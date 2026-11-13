# Contrato de autorización entre servicios — ApuntesUCT (#445)

**Estado:** Pendiente de consenso. Las secciones marcadas como “propuestas” requieren acuerdo explícito entre los equipos; al cerrar el consenso se actualizará el estado a “Consensuado”.

**Base:** `origin/main` (`be5d9ff`)  
**Alcance:** API Gateway, Auth Service, Catalog Service, Material Service, Search Service y futuros servicios internos.

Este documento define el contrato de autorización **cliente → Gateway → microservicios** y las reglas mínimas para llamadas entre servicios. Su objetivo es que todos los servicios interpreten de forma consistente la identidad, el contexto de autor y los errores de autorización.

## 1. Objetivos

- Tener un único mecanismo de propagación de identidad/autorización desde el Gateway hacia los microservicios.
- Definir qué claims/campos representan al usuario autenticado y cómo se obtiene el contexto de autor (p. ej. subidas/versiones de Material).
- Establecer respuestas de error consistentes (`401`, `403`, `502/503` según caso).
- Permitir una transición segura desde el estado actual (Auth mock + contexto local de autor en Material) hacia autenticación/autorización verificable.
- Coordinar el registro público (#440) con el contrato de identidad: `user.id` será la base del futuro claim `sub`.

## 2. Actores y flujo

1. **Cliente (Web/Mobile/externo)** envía solicitudes al **API Gateway** (`:3000`, prefijo `/api/v1`).
2. **Auth Service** expone el registro público (`POST /api/v1/auth/register`) y emite credenciales/tokens de sesión (actualmente login mock; objetivo: JWT verificable; login real/JWT en #441).
3. **Gateway** actúa como punto único de entrada y **propaga** el contexto de autorización a los microservicios destino sin alterarlo, salvo lo necesario para el proxy (p. ej. reescritura puntual de rutas ya definida, reconstrucción de body consumido por Nest).
4. **Microservicios de dominio** (Material, Catalog, Search, etc.) aplican las reglas de autorización del recurso:
   - resuelven identidad/autor desde el contrato definido;
   - autorizan la operación (autenticado, rol/propiedad cuando aplique);
   - responden con errores consistentes.

Llamadas **servicio → servicio** internas (si se incorporan) deben usar el mismo contrato o un mecanismo interno explícitamente documentado (token de servicio / mTLS / red confiable). No deben reutilizar tokens de usuario sin una razón explícita y auditada.

## 3. Estado actual (referencia en `main`)

| Componente | Comportamiento actual | Implicancia |
| --- | --- | --- |
| Gateway (`backend/api-gateway/src/modules/proxy/service-proxy.ts`) | Proxy HTTP con `httpxy`; reenvía la solicitud al upstream. Reconstruye `Content-Length`/body para JSON y `x-www-form-urlencoded` cuando Nest ya consumió el body; los streams no parseados pasan directo. Responde `502` `{ statusCode, message }` si el servicio no está disponible. | El Gateway es el lugar natural para propagar `Authorization` y, en el futuro, validar/enriquecer contexto. |
| Auth (`POST /api/v1/auth/login`) | Login **mock**: no verifica credenciales reales. Devuelve JWT **sin firma** (`alg: none`) con claims como `mock: true`, `sub`, `email`, `role`, `iat`, `exp`, además de `user`. | **No** debe considerarse prueba de identidad fuerte. Sirve para integración/transición. |
| Auth (`POST /api/v1/auth/register`) | Registro público planificado en #440 (sin token). Ver sección 4 para el contrato coordinado. | Define el `user.id` que luego debe alimentar `sub`. |
| Material (`MaterialAuthorProvider`) | Resuelve autor desde configuración local **solo en desarrollo** (`NODE_ENV=development`, `MATERIAL_LOCAL_AUTHOR_ENABLED=true`, `MATERIAL_LOCAL_UPLOADER_ID` UUID). Si no hay contexto válido, responde `401`. | Las operaciones que requieren autor (subida, creación de versión) dependen hoy de este mecanismo transitorio; el contrato objetivo debe reemplazarlo/compatibilizarlo. |
| Search/Catalog | Consultas de lectura con filtros/validaciones propias; disponibilidad/dependencias se reflejan en `400/502/503` según contrato existente. | La autorización de lectura/escritura por endpoint debe declararse explícitamente al aplicar este contrato. |

## 4. Registro público (#440)

`POST /api/v1/auth/register` — **público, sin token**. Crea la cuenta y **no inicia sesión**: no devuelve tokens.

### 4.1 Request

```json
{
  "name": "Nelson Quiñinao",
  "email": "nquininao2023@alu.uct.cl",
  "password": "PasswordSegura123!"
}
```

### 4.2 Validaciones

| Campo | Regla |
| --- | --- |
| `name` | 3–100 caracteres. |
| `email` | Hasta 254 caracteres; se normaliza a minúsculas y se recortan espacios exteriores. Debe pertenecer **exclusivamente** a `@uct.cl` o `@alu.uct.cl`. |
| `password` | 8–128 caracteres; no puede estar formada solo por espacios; **no modificar** (sin `trim` ni transformaciones). |

Los campos adicionales enviados por el cliente se **descartan**: no se persisten ni se reflejan en la respuesta.

### 4.3 Respuesta `201`

```json
{
  "user": {
    "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
    "name": "Nelson Quiñinao",
    "email": "nquininao2023@alu.uct.cl",
    "role": "STUDENT",
    "active": true
  }
}
```

No devuelve contraseña, hash ni tokens. El registro asigna **siempre** `role: STUDENT` y `active: true`.

### 4.4 Errores

| Código | Caso |
| --- | --- |
| `400` | Datos inválidos (nombre, correo, contraseña o formato). |
| `409` | Correo duplicado, **incluso con diferencias de mayúsculas o espacios exteriores** (comparación sobre el correo normalizado). |

### 4.5 Roles

| Rol | Responsabilidades propuestas |
| --- | --- |
| `STUDENT` | Subir material, crear versiones propias, buscar/descargar, calificar y reportar según contrato. |
| `MODERATOR` | Revisar/verificar/rechazar material, gestionar reportes y moderar contenido. |
| `ADMIN` | Gestionar usuarios/roles y configuración del sistema; **a decidir** si incluye todos los permisos de moderación. |

**Pendiente de consenso:** responsabilidades exactas de `STUDENT`, `MODERATOR` y `ADMIN`, y si `ADMIN` incluye todos los permisos de `MODERATOR`.

### 4.6 Identidad y transición

- El futuro claim `sub` del JWT debe usar **el mismo UUID** que `user.id`.
- El login real y la emisión de JWT quedan fuera de #445, en **#441**.

## 5. Contrato objetivo propuesto (pendiente de consenso)

### 5.1 Transporte de credenciales (cliente → Gateway → servicio)

- **Mecanismo principal:** cabecera HTTP `Authorization: Bearer <access_token>`.
- **Propagación:** el Gateway **debe reenviar** `Authorization` al microservicio destino sin modificar el token (salvo decisiones de seguridad explícitas aprobadas, p. ej. intercambio por token interno; en ese caso debe documentarse la equivalencia).
- **No usar** parámetros de query para tokens. No registrar tokens en logs.

### 5.2 Token de acceso (objetivo)

- Formato objetivo: **JWT firmado** (algoritmo asimétrico recomendado, p. ej. RS256/ES256) emitido por Auth Service.
- El Gateway y/o los servicios deben **verificar** firma, expiración (`exp`), emisor (`iss`) y audiencia (`aud`) cuando la verificación esté habilitada.
- **Transición:** mientras exista login mock (`alg: none`, `mock: true`), los tokens mock **no** otorgan confianza de identidad en entornos productivos. Su aceptación debe estar limitada a entornos controlados de desarrollo/integración y explícitamente configurada.

### 5.3 Claims / contexto de identidad mínimo

Campos mínimos acordados para identificar al usuario autenticado:

| Campo | Claim / origen | Uso |
| --- | --- | --- |
| Identificador de usuario | `sub` (UUID; **debe coincidir con `user.id`** del registro) | **Autor/propietario** de recursos (p. ej. `authorId` en Material). Obligatorio para operaciones que requieren autor. |
| Correo | `email` | Información de perfil/auditoría; no usar como clave primaria. |
| Rol | `role` | Autorización por rol cuando aplique (`STUDENT`, `MODERATOR`, `ADMIN`). |
| Marca de mock | `mock` (actual) | Solo transición/integración; no usar para autorización real en producción. |
| Expiración | `exp` | Rechazo de tokens expirados. |

El **contexto de autor** para Material (subida, `POST /materials`, `POST /materials/:id/versions`) debe resolverse al identificador autenticado (`sub`) validado por el contrato, no a un ID enviado libremente por el cliente.

### 5.4 Autorización por operación

- **Públicas / sin contexto de usuario:** healthchecks, `POST /api/v1/auth/register` y endpoints explícitamente públicos (definir por ruta). El Gateway/servicio no debe exigir `Authorization` salvo que el endpoint lo requiera.
- **Autenticadas:** requieren identidad válida (`401` si falta/inválida/expirada).
- **Autorizadas:** requieren además permisos (rol, propiedad del recurso, afiliación). Responder `403` cuando la identidad es válida pero no tiene permiso (p. ej. versionar material ajeno, según regla de negocio).
- **Búsqueda/Catalog/lecturas:** el nivel de acceso (público o autenticado) debe quedar fijado por endpoint en su especificación; este contrato define *cómo* se transmite/valida la identidad cuando aplique.

### 5.5 Errores y semántica HTTP

| Código | Significado en este contrato | Ejemplo |
| --- | --- | --- |
| `400` | Solicitud inválida (validación, IDs, reglas de negocio no relacionadas con credenciales). | `materialId` inválido, multipart inválido, `sortBy` inválido, datos de registro inválidos. |
| `401` | No autenticado o credencial inválida/ausente/expirada cuando el endpoint requiere autenticación. | Falta `Authorization`, token inválido/expirado. |
| `403` | Autenticado pero sin permiso para la operación/recurso. | Usuario no es autor del material al crear versión. |
| `409` | Conflicto de unicidad. | Correo duplicado en registro (comparación normalizada). |
| `502` | Servicio upstream no disponible o respuesta inválida de dependencia (según proxy/contrato del servicio). | Gateway no alcanza Material/Auth; dependencia inválida. |
| `503` | Dependencia no disponible para completar la operación (cuando el servicio lo distingue). | Almacenamiento/dependencia de Search no disponible. |

Formato de error: mantener compatibilidad con Nest (`{ statusCode, message, error? }`, con `message` string o arreglo). El Gateway puede responder `502` como `{ statusCode, message }` sin `error`; los clientes deben tolerar ambas formas.

### 5.6 Confianza entre servicios

- Los microservicios **no** deben confiar ciegamente en headers arbitrarios enviados por clientes externos. El Gateway es el borde de entrada.
- Si se adoptan headers internos derivados (p. ej. `X-User-Id` inyectado por Gateway tras validación), deben:
  - generarse **solo** por un componente confiable (Gateway tras verificación),
  - rechazarse o ignorarse si provienen directamente del cliente,
  - documentarse como parte formal del contrato.
- Hasta que exista verificación centralizada, los servicios que requieren identidad fuerte deben declararlo y usar el mecanismo transitorio aprobado (hoy, contexto local de desarrollo en Material) sin exponer bypass en producción.

## 6. Plan de adopción (para consenso/seguimiento)

1. **Consensuar** este documento (alcance, claims, errores, roles, transición mock→JWT real).
2. **Gateway:** confirmar/restringir propagación de `Authorization`; definir si valida JWT o delega validación a servicios.
3. **Auth:** registrar según #440; evolucionar de mock a JWT firmado y claves/configuración (`iss`, `aud`, expiración, rotación si aplica) en #441.
4. **Material (y otros servicios con autor):** reemplazar `MaterialAuthorProvider` local por resolución desde identidad verificada (`sub`) manteniendo compatibilidad controlada en desarrollo.
5. **Pruebas/Docs:** actualizar OpenAPI, Postman e integración (Web/Mobile) con requisitos `401/403/409` y flujo de token real.
6. **Service-to-service:** definir credenciales internas solo cuando exista un caso real.

## 7. Criterios de aceptación sugeridos para #445

- [ ] Contrato escrito, versionado en el repositorio y revisado por los equipos involucrados (INT2/INT4/servicios).
- [ ] Registro público (`POST /api/v1/auth/register`) coordinado: validaciones, `201`, errores `400/409`, rol `STUDENT`, `active: true`, descarte de campos extra.
- [ ] Responsabilidades de `STUDENT`, `MODERATOR` y `ADMIN` definidas; decisión explícita sobre si `ADMIN` incluye todos los permisos de moderación.
- [ ] Define propagación de `Authorization` Gateway→servicios y claims mínimos (`sub` = `user.id`, `role`, `exp`; transición `mock`).
- [ ] Define semántica `401` vs `403` (y `400/409/502/503` donde aplique) y tratamiento transitorio del login mock/contexto local de Material.
- [ ] Identifica impactos y siguientes tareas de implementación (Gateway/Auth/Material/docs; login/JWT en #441).

## 8. Referencias

- `backend/api-gateway/src/modules/proxy/service-proxy.ts` (proxy y manejo de body/502).
- `backend/auth-service/src/presentation/auth/auth.controller.ts` (login mock, JWT sin firma).
- `backend/material-service/src/infrastructure/auth/material-author.provider.ts` (contexto de autor transitorio).
- `backend/material-service/src/presentation/controllers/material.controller.ts` y `material-version.controller.ts` (operaciones que requieren autor).
- `docs/api/README.md`, `docs/mobile/integracion-api-mobile.md`, `docs/checklist-integracion-api-mobile.md` (integración cliente/Gateway).
- #440 (registro público) y #441 (login real/emisión de JWT).