# Aprobación y rechazo de materiales: instalación y verificación

Esta entrega implementa APPROVE/REJECT, consulta privada para revisión y seguimiento de operaciones. No implementa VERIFY, RETIRE, REOPEN ni endpoints de calificaciones/reportes/favoritos. El contrato completo sigue describiendo esos trabajos posteriores.

## 1. Aplicar el paquete

El ZIP de entrega contiene únicamente archivos nuevos/modificados con rutas relativas a la raíz de ApuntesUCT. No sustituye el proyecto completo. Antes de copiarlo, crea una rama y conserva los cambios locales. Si un archivo cambió desde el ZIP revisado, combina el cambio en vez de sobrescribirlo.

Desde la raíz del proyecto, en PowerShell:

```powershell
git switch -c feat/quality-approve-reject
cd backend
npm ci
npm run prisma:generate --workspace=auth-service --workspace=material-service --workspace=quality-service
npm run build --workspace=auth-service --workspace=material-service --workspace=quality-service --workspace=api-gateway
```

No se necesita instalar globalmente Prisma ni Jest. El lockfile actualizado forma parte de la entrega.

## 2. Ejecutar primero la prueba automática completa

Utiliza bases de desarrollo/prueba llamadas `auth_db`, `material_db` y `quality_db`. Pueden estar en las instancias PostgreSQL del Docker Compose existente. Los valores de usuario, contraseña y puerto deben corresponder a tu entorno. No copies las credenciales de ejemplo como si fueran reales.

```powershell
# Desde backend; sustituir los marcadores por la configuración de prueba.
$env:MODERATION_TEST_AUTH_DATABASE_URL = 'postgresql://<usuario>:<clave>@127.0.0.1:<puerto-auth>/auth_db'
$env:MODERATION_TEST_MATERIAL_DATABASE_URL = 'postgresql://<usuario>:<clave>@127.0.0.1:<puerto-material>/material_db'
$env:MODERATION_TEST_QUALITY_DATABASE_URL = 'postgresql://<usuario>:<clave>@127.0.0.1:<puerto-quality>/quality_db'
npm run test:moderation
```

La prueba genera claves temporales, crea usuarios/materiales propios, aplica migraciones en esquemas únicos `moderation_test_*`, inicia cuatro servidores HTTP en puertos libres y elimina sus esquemas al finalizar. No requiere un moderador creado manualmente. No usa tokens mock. Los JWT se firman con claves de prueba.

Usa PostgreSQL y HTTP reales. El almacenamiento de archivos se sustituye por un adaptador en memoria; esta prueba no acredita integración con MinIO. El worker se ejecuta de forma controlada para provocar y comprobar carreras y fallos. La recuperación crea otra instancia del worker sobre la misma outbox; no simula un reinicio del sistema operativo.

Resultado esperado: todas las pruebas pasan, incluyendo:

- 401 sin token, firma inválida, expiración o mock; 403 para STUDENT.
- Snapshot y descarga privada autorizados, correlación de auditoría y ausencia de storageKey.
- Aprobación: 202 → APPLIED/PUBLISHED; rechazo con motivo → APPLIED/REJECTED.
- Autorrevisión denegada para MODERATOR y ADMIN.
- Repetición de clave, conflicto de payload y decisiones concurrentes.
- Rollback de aceptación sin operación/evidencia parcial.
- Pérdida de respuesta después del commit de Material, sin duplicar el efecto.
- Cuenta inactiva, rol perdido y tokenVersion revocada.
- Nueva versión devuelve el agregado a revisión e invalida una decisión obsoleta.
- Rutas internas no expuestas por Gateway y rechazo de JWT de usuario en Material interno.
- Dos entregas concurrentes de una operación devuelven el mismo recibo.
- Caída de Material, concesión vencida, respuesta inconsistente y recuperación.
- Fallo de Auth sin conceder acceso.

## 3. Regresiones

Desde `backend`:

```powershell
npm run test:ci --workspace=quality-service --workspace=material-service --workspace=auth-service --workspace=api-gateway
npm run test:e2e --workspace=quality-service
npm run lint --workspace=quality-service --workspace=material-service --workspace=auth-service --workspace=api-gateway

$env:QUALITY_TEST_DATABASE_URL = $env:MODERATION_TEST_QUALITY_DATABASE_URL
npm run test:integration --workspace=quality-service

# Material usa esquemas desechables propios.
$env:MATERIAL_TEST_DATABASE_URL = $env:MODERATION_TEST_MATERIAL_DATABASE_URL
node --test material-service/test/persistence.integration.cjs material-service/test/create-material-version.integration.cjs material-service/test/materials.integration.cjs

cd ..
node scripts/validate-quality-contracts.cjs
git diff --check
```

Los scripts existentes de Material ya incluyen su configuración de Jest/ESM cuando corresponde. No hace falta cambiar sus opciones globales para ejecutar `test:moderation`.

El workflow añade Quality a la matriz E2E y un job específico de integración. Los resultados locales no sustituyen los checks del PR: revisar su ejecución al subirlo.

## 4. Configurar y probar manualmente

### Migraciones y despliegue

Detén los procesos locales implicados. Cada servicio debe tener en su `.env` su propia DATABASE_URL. Desde backend, sin una DATABASE_URL global que sobrescriba todas las demás:

```powershell
npm run prisma:deploy --workspace=auth-service
npm run prisma:deploy --workspace=material-service
npm run prisma:deploy --workspace=quality-service
```

Son migraciones nuevas. No editar las ya aplicadas ni usar `migrate reset`. El renombrado WITHDRAWN → RETIRED requiere coordinar Material y sus consumidores; no dejar instancias con el enum anterior ejecutándose durante ese cambio. La revisión de materiales existentes empieza en 1.

### Claves y configuración

Reutiliza la clave de Auth, su emisor y audiencia existentes. Crea una identidad distinta para Quality, fuera del repositorio:

```powershell
node scripts/generate-quality-service-key.cjs "$env:USERPROFILE\apuntesuct-quality-keys"
```

El generador no sobrescribe archivos existentes. Configura:

| Proceso | Variables |
| --- | --- |
| Auth | Configuración actual de Auth + QUALITY_SERVICE_PUBLIC_KEY |
| Material | Configuración actual de Material + QUALITY_SERVICE_PUBLIC_KEY |
| Quality | DATABASE_URL de quality_db; JWT_ACCESS_PUBLIC_KEY de Auth; JWT_ISSUER; JWT_AUDIENCE; QUALITY_SERVICE_PRIVATE_KEY; AUTH_INTERNAL_URL; MATERIAL_INTERNAL_URL; QUALITY_MODERATION_ENABLED=true |
| Gateway | QUALITY_SERVICE_URL=http://127.0.0.1:3004; conservar configuración actual |

Los valores de claves son el contenido PEM, no sus rutas. Por ejemplo, en las terminales de Auth y Material:

```powershell
$env:QUALITY_SERVICE_PUBLIC_KEY = Get-Content "$env:USERPROFILE\apuntesuct-quality-keys\quality-service-public.pem" -Raw
```

Solo en la terminal de Quality:

```powershell
$env:QUALITY_SERVICE_PRIVATE_KEY = Get-Content "$env:USERPROFILE\apuntesuct-quality-keys\quality-service-private.pem" -Raw
$env:JWT_ACCESS_PUBLIC_KEY = Get-Content '<ruta-a-la-clave-publica-de-Auth.pem>' -Raw
$env:JWT_ISSUER = 'apuntesuct-auth' # Debe coincidir con Auth.
$env:JWT_AUDIENCE = 'apuntesuct-api' # Debe coincidir con Auth.
$env:AUTH_INTERNAL_URL = 'http://127.0.0.1:3001'
$env:MATERIAL_INTERNAL_URL = 'http://127.0.0.1:3003'
$env:QUALITY_MODERATION_ENABLED = 'true'
$env:QUALITY_WORKER_ENABLED = 'true'
```

En producción se exige HTTPS para los orígenes internos y una distribución segura de claves. La configuración de desarrollo anterior no es una receta de despliegue productivo. Los logs de auditoría deben enviarse a un destino persistente con acceso restringido.

Inicia cada proceso en una terminal distinta, desde backend:

```powershell
npm run start:dev --workspace=auth-service
npm run start:dev --workspace=material-service
npm run start:dev --workspace=quality-service
npm run start:dev --workspace=api-gateway
```

Cada línea corresponde a una terminal. Material también necesita sus dependencias actuales para cargar/descargar archivos. Para preparar material mediante la UI, conserva Catalog/MinIO y los demás servicios habituales.

### Usuario y material

Usa una cuenta de moderador activa y un material PENDING_REVIEW subido por otra cuenta. La asignación de roles pertenece a Auth; no se añade una ruta pública para convertir usuarios en moderadores. Si necesitas una cuenta de desarrollo, asígnale el rol mediante las herramientas administrativas de Auth de tu entorno y vuelve a iniciar sesión.

```powershell
$base = 'http://localhost:3000/api/v1/quality'
$credencial = Get-Credential -Message 'Cuenta MODERATOR o ADMIN de desarrollo'
$loginBody = @{ email=$credencial.UserName; password=$credencial.GetNetworkCredential().Password } | ConvertTo-Json
$sesion = Invoke-RestMethod -Method Post -Uri 'http://localhost:3000/api/v1/auth/login' -ContentType 'application/json' -Body $loginBody
$loginBody = $null
$headers = @{ Authorization="Bearer $($sesion.accessToken)" }

$pagina = Invoke-RestMethod -Uri "$base/moderation/materials" -Headers $headers
$pagina.items | Select-Object id,title,status,revision,uploaderId
$materialId = '<id-de-un-material-de-otro-autor>'
$snapshot = Invoke-RestMethod -Uri "$base/moderation/materials/$materialId" -Headers $headers

$clave = [guid]::NewGuid().ToString()
$decisionHeaders = @{ Authorization=$headers.Authorization; 'Idempotency-Key'=$clave }
$body = @{ action='APPROVE'; expectedRevision=$snapshot.revision } | ConvertTo-Json
$operacion = Invoke-RestMethod -Method Post -Uri "$base/moderation/materials/$materialId/decisions" -Headers $decisionHeaders -ContentType 'application/json' -Body $body
$operacion | Select-Object id,state,result,failure

# Consultar hasta observar APPLIED o FAILED; 202 no significa publicado.
$seguimiento = Invoke-RestMethod -Uri "$base/moderation/operations/$($operacion.id)" -Headers $headers
$seguimiento | Select-Object id,state,result,failure
```

Para rechazar, usa otro material pendiente y cambia el cuerpo por:

```powershell
$body = @{ action='REJECT'; expectedRevision=$snapshot.revision; reason='Documento incompleto.' } | ConvertTo-Json
```

Obtén primero el snapshot de ese otro material y genera una clave nueva. Para probar un replay, conserva exactamente la misma ruta, clave y cuerpo de la solicitud original: no vuelvas a generar la clave ni la revisión.

### Comprobación observable

- APPROVE aplicada: detalle y descarga públicos de Material disponibles; revision incrementada una vez, verified=false.
- REJECT aplicada: detalle/descarga públicos devuelven 404; material ausente del listado público.
- Rechazo sin motivo: 400, sin operación nueva.
- Token STUDENT: 403; sin token: 401 y WWW-Authenticate.
- Misma clave/cuerpo: mismo operationId. Misma clave/otro cuerpo: 409.
- Nueva clave sobre material ya publicado: conflicto; no hay otra aprobación silenciosa.
- Si Material falla después de aceptar: PENDING_APPLICATION hasta recuperar conectividad; no cambiar la clave para reintentar.

## 5. Alcance y cierre de la tarea

Verifica el resultado automático y adjunta al PR los logs/resumen, commit probado y configuración de prueba sin secretos. El perfil de servicio nuevo y la integración con Auth deben revisarse como parte de este PR. No marcar el registro histórico de acuerdos de S3-04 como completado inventando aprobaciones.

El flujo implementado cubre los criterios de aprobación/rechazo. La aceptación final requiere los checks del repositorio y la revisión del equipo; no queda acreditada por copiar archivos ni por este documento.
