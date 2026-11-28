# Recepción y resolución de reportes: implementación y pruebas

Base: contenido de `ApuntesUCT(2).zip` suministrado como main. No incluye ni necesita los endpoints, outbox, revisión o recibos del PR de aprobación/rechazo pendiente. El archivo ZIP de entrega contiene sólo archivos nuevos/modificados.

## 1. Flujo implementado

1. Gateway reenvía las rutas `/api/v1/quality` a Quality.
2. Quality consulta `GET /api/v1/auth/access-context` con el Bearer del solicitante. Auth verifica firma RS256, issuer, audience, expiración y claims con su mecanismo existente; después comprueba usuario activo, rol vigente y tokenVersion en su propia base. Sin token/revocado: 401; inactivo o rol insuficiente: 403; Auth no disponible: 503. Nunca se confía en x-user-id/x-role.
3. POST normaliza motivo/detalles y resuelve idempotencia por actor/familia/clave. Para una creación nueva consulta el detalle público de Material por REST; sólo admite PUBLISHED. Guarda uploaderId como referencia interna de autoría, sin FK ni acceso a material_db.
4. Una transacción de Quality guarda Report OPEN, historial inicial y snapshot de respuesta idempotente. Un índice único parcial impide dos OPEN/IN_REVIEW por usuario/material, incluso con concurrencia.
5. El denunciante consulta sus reportes, aunque Material se oculte. MODERATOR/ADMIN consultan la bandeja. Una lectura ajena de STUDENT devuelve 404. Ningún ReportDto expone título, enlace, estado privado, archivo o referencia interna de autoría.
6. PATCH autentica/autoriza antes de resolver replay; para una operación nueva bloquea el reporte, comprueba autoría, expectedUpdatedAt y transición. Actualiza reporte, historial y snapshot idempotente en una transacción. updatedAt avanza como mínimo 1 ms.
7. Crear o resolver no cambia Material ni su verificación. RETIRE/REOPEN pertenecen a decisiones separadas del contrato; esta tarea no implementa esos comandos.

| Método/ruta relativa a /api/v1/quality | Acceso | Resultado |
| --- | --- | --- |
| POST /materials/{materialId}/reports | Cualquier rol autenticado activo | 201 nuevo / 200 replay |
| GET /reports/me | Usuario activo | Página propia |
| GET /reports/{reportId} | Denunciante o MODERATOR/ADMIN | ReportDto / 404 |
| GET /moderation/reports | MODERATOR/ADMIN | Página; status opcional, sin filtro devuelve todos |
| PATCH /moderation/reports/{reportId} | MODERATOR/ADMIN ajeno al reporte y al material | ReportDto / conflictos 409 |

POST/PATCH exigen Idempotency-Key UUID. Misma clave y mismo payload normalizado devuelve el snapshot original, incluso tras cambios posteriores. Una clave con contenido distinto devuelve 409. Se retienen claves/snapshots sin caducidad automática. Las familias de creación y tratamiento son independientes.

Motivos: INAPPROPRIATE_CONTENT, COPYRIGHT, INCORRECT_INFORMATION, BROKEN_RESOURCE y OTHER. OTHER exige detalles. Los textos justificativos se recortan y tienen máximo 2000 caracteres. RESOLVED y DISMISSED requieren resolutionNote. OPEN permite IN_REVIEW/RESOLVED/DISMISSED; IN_REVIEW permite RESOLVED/DISMISSED. No se reabren terminales.

La comprobación de publicación ocurre en la lectura autoritativa de Material; un retiro concurrente posterior no revoca el reporte aceptado. No hay transacción distribuida. La referencia de uploaderId se basa en la autoría inmutable del modelo actual: si se incorpora transferencia de autoría deberá revisarse este contrato interno.

## 2. Integración en una rama independiente

No copies este paquete sobre la rama de aprobación/rechazo. Guarda primero cualquier cambio local; crea la rama desde main actualizado:

```powershell
git switch main
git pull --ff-only
git switch -c feat/quality-reports
# Copiar los archivos del paquete conservando las rutas.
cd backend
npm ci
npm run prisma:generate --workspace=auth-service --workspace=material-service --workspace=quality-service
npm run build --workspace=auth-service --workspace=material-service --workspace=quality-service --workspace=api-gateway
```

Si main cambió respecto al ZIP suministrado, combina los cambios en vez de sobrescribir archivos. Este PR incluye una precondición de Auth propia; no importa código desde la rama pendiente.

### Coincidencias con el PR pendiente

Ambas tareas necesitan revocación por tokenVersion y enrutamiento de Quality. La migración `20261127000000_access_token_version` se entrega con el mismo nombre y contenido que en el paquete anterior: al integrar ambas ramas debe conservarse una sola copia, sin crear una segunda migración que añada la misma columna.

Conservar los registros de módulos/controladores de ambas funcionalidades y una sola ruta proxy. Revisar conflictos en AuthModule, QualityModule, login, password recovery, esquema Prisma, scripts y workflow. La integración de reportes usa el endpoint de identidad propia descrito aquí; no necesita la credencial privada Quality→Material del otro PR.

## 3. Prueba automática completa (PowerShell)

Desde `backend`, levanta tus PostgreSQL de pruebas y copia las DATABASE_URL reales de los servicios correspondientes. NO ejecutes los marcadores de ejemplo literalmente. Los puertos son de PostgreSQL publicados al host, no 3001/3003/3004.

```powershell
$env:REPORTS_TEST_AUTH_DATABASE_URL = 'CONEXION_POSTGRESQL_REAL_A_AUTH_DB'
$env:REPORTS_TEST_MATERIAL_DATABASE_URL = 'CONEXION_POSTGRESQL_REAL_A_MATERIAL_DB'
$env:REPORTS_TEST_QUALITY_DATABASE_URL = 'CONEXION_POSTGRESQL_REAL_A_QUALITY_DB'
npm run test:reports
```

Usa bases llamadas auth_db, material_db y quality_db, con permiso para crear esquemas. Cada prueba crea esquemas únicos `reports_test_*`, aplica migraciones allí, genera claves RSA temporales e inicia Auth, Material, Quality y Gateway en puertos libres. Al finalizar limpia los esquemas y las claves. No exige cuentas manuales. No utiliza producción.

Se prueba PostgreSQL y HTTP reales. Material expone su controlador/servicio real y usa recursos LINK; no se prueba MinIO ni descargas. Los módulos de Auth/Material se acotan a los controladores necesarios; Quality/Gateway usan sus módulos de aplicación. No equivale a un despliegue completo con Docker/UI.

Después:

```powershell
npm run test:ci --workspace=quality-service --workspace=auth-service --workspace=api-gateway
npm run test:e2e --workspace=quality-service
npm run test:e2e --workspace=api-gateway -- --runInBand
npm run lint --workspace=quality-service --workspace=auth-service --workspace=api-gateway
$env:QUALITY_TEST_DATABASE_URL = $env:REPORTS_TEST_QUALITY_DATABASE_URL
npm run test:integration --workspace=quality-service
cd ..
node scripts/validate-quality-contracts.cjs
git diff --check
```

El workflow añade un trabajo de integración de reportes con bases PostgreSQL desechables. Su ejecución remota sólo queda acreditada cuando GitHub complete los checks del PR.

## 4. Migraciones del entorno local

Las pruebas temporales NO migran el esquema public usado al arrancar normalmente los servicios. Detén Auth y Quality antes de migrarlos. Cada `.env` debe apuntar a su propia base; evita una DATABASE_URL de terminal que sobrescriba ambas.

Desde backend:

```powershell
npm run prisma:deploy --workspace=auth-service
npm run prisma:deploy --workspace=quality-service
npm run prisma:generate --workspace=auth-service --workspace=quality-service
```

Auth añade token_version default 0. Login lo incorpora al JWT y recuperación de contraseña lo incrementa. El nuevo endpoint access-context comprueba esta versión; no se afirma que todos los verificadores antiguos del proyecto ya consulten revocación.

Quality añade resolution_note/material_uploader_id, ReportHistory y ReportMutation, categorías válidas y un índice parcial. No borra ni resuelve automáticamente reportes preexistentes. Antes de desplegar en una base con datos, comprobar:

```sql
SELECT user_id, material_id, COUNT(*)
FROM reports WHERE status IN ('OPEN', 'IN_REVIEW')
GROUP BY user_id, material_id HAVING COUNT(*) > 1;
SELECT id, reason FROM reports
WHERE reason NOT IN ('INAPPROPRIATE_CONTENT','COPYRIGHT','INCORRECT_INFORMATION','BROKEN_RESOURCE','OTHER');
```

Si hay filas, conciliar los registros con el responsable antes de migrar; no eliminar datos para hacer pasar el índice. La migración Quality es transaccional. Una migración fallida puede requerir reparar su registro conforme al estado real antes de reintentar.

P3005 (esquema no vacío sin historial inicial reconocido): detenerse y comparar esquema e historial para establecer baseline. No usar migrate reset ni marcar todas las migraciones como aplicadas a ciegas. prisma generate sólo genera cliente, no crea columnas. P2022 token_version indica que la base real todavía no fue migrada o que se está usando otra conexión/esquema.

Los reportes antiguos no reciben un uploaderId inventado. Al tratarlos se intenta recuperarlo del detalle público. Si Material está oculto/no existe se responde 503 y se requiere conciliación de esa referencia mediante evidencia autorizada del equipo; nunca se permite autorresolución por desconocer el propietario.

## 5. Configuración y comprobación manual

En `.env` de Quality (orígenes sin rutas ni credenciales):

```dotenv
QUALITY_REPORTS_AUTH_URL=http://127.0.0.1:3001
QUALITY_REPORTS_MATERIAL_URL=http://127.0.0.1:3003
```

En Gateway: `QUALITY_SERVICE_URL=http://127.0.0.1:3004`. En Docker usa los nombres DNS internos. En producción los orígenes de las dependencias de reportes deben usar HTTPS. Un origen ausente/inválido falla cerrado con 503. Auth conserva JWT_PRIVATE_KEY_PATH/JWT_ISSUER/JWT_AUDIENCE y su configuración existente. No se crean claves productivas nuevas en este paquete.

Arranca Auth, Material, Quality y Gateway con sus dependencias. Desde backend, una terminal por comando:

```powershell
npm run start:dev --workspace=auth-service
npm run start:dev --workspace=material-service
npm run start:dev --workspace=quality-service
npm run start:dev --workspace=api-gateway
```

Prepara un material PUBLISHED en tu entorno de pruebas y cuentas activas de estudiante y moderador/admin distinto del autor. Esta tarea no publica materiales ni proporciona rutas para elevar roles. Si todavía no hay publicación funcional, utiliza fixtures autorizados del entorno o la prueba automática que prepara sus propios datos.

```powershell
$base = 'http://localhost:3000/api/v1/quality'
$cred = Get-Credential -Message 'Cuenta de estudiante de pruebas'
$login = @{email=$cred.UserName; password=$cred.GetNetworkCredential().Password} | ConvertTo-Json
$sesion = Invoke-RestMethod -Method Post -Uri 'http://localhost:3000/api/v1/auth/login' -ContentType 'application/json' -Body $login
$login = $null
$headers = @{Authorization="Bearer $($sesion.accessToken)"; 'Idempotency-Key'=[guid]::NewGuid().ToString()}
$materialId = 'UUID_REAL_DEL_MATERIAL_PUBLICADO'
$body = @{reason='BROKEN_RESOURCE'; details='El enlace no permite acceder al recurso.'} | ConvertTo-Json
$reporte = Invoke-RestMethod -Method Post -Uri "$base/materials/$materialId/reports" -Headers $headers -ContentType 'application/json' -Body $body
Invoke-RestMethod -Uri "$base/reports/me" -Headers $headers
# Repetir POST con exactamente los mismos headers/ruta/body devuelve el mismo reporte.
```

Inicia sesión con la cuenta moderadora mediante el mismo flujo y guarda su accessToken en `$tokenModerador`:

```powershell
$adminHeaders = @{Authorization="Bearer $tokenModerador"; 'Idempotency-Key'=[guid]::NewGuid().ToString()}
Invoke-RestMethod -Uri "$base/moderation/reports?status=OPEN" -Headers $adminHeaders
$actual = Invoke-RestMethod -Uri "$base/reports/$($reporte.id)" -Headers $adminHeaders
$decision = @{status='RESOLVED'; expectedUpdatedAt=$actual.updatedAt; resolutionNote='Se revisó el reporte y se registró la atención.'} | ConvertTo-Json
Invoke-RestMethod -Method Patch -Uri "$base/moderation/reports/$($reporte.id)" -Headers $adminHeaders -ContentType 'application/json' -Body $decision
```

Comprueba que Material mantiene exactamente su estado/verified. La creación no retira y resolver tampoco. Si el caso requiere retiro, debe solicitarse por el flujo de moderación separado cuando esté disponible.

## 6. Evidencia y PR

Adjuntar resultados de test:reports, suites de servicios, persistencia, lint/build y checks del PR. Incluir el commit probado y resumir configuración sin credenciales. La validación local no equivale a aprobación del revisor ni despliegue productivo. Revisar el endpoint Auth nuevo y la política de autoría histórica con los responsables al revisar este PR.
