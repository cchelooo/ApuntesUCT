# Soporte de integración con Taller 4 Mobile

**INT2 → INT4 · Sprint 1** · Actualizado tras revisión de la entrega de INT4.

> **Actualización de red de Sprint 2 (#272, 7 de octubre de 2026):** Catalog y
> el listado básico de Material reutilizan `apiclientProvider`, con
> `ApiConfig.gatewayBaseUrl` como única entrada HTTP. Mobile ya no lee
> `CATALOG_SERVICE_URL`. La conexión real y los errores 502 se verificaron contra
> Gateway, Catalog, Material y PostgreSQL temporales. Búsqueda sigue con fixtures;
> los providers HTTP de Material están preparados para su integración en pantallas.
> Consultar [`mobile/README.md`](../../mobile/README.md#configuración-de-red-y-conexión-con-api-gateway).
> El resto de contratos y resultados
> de Sprint 1 de esta guía conservan su carácter histórico, especialmente Auth;
> no constituyen una revisión actual de todas las funcionalidades del Backend.

> **Referencia de documentación:** rama actualizada con `main` (merge de `origin/main`), toma como referencia el commit `7d80289` (merge PR #187, script de seeding).
>
> Convención de estados usada en todo el documento:
> - **Implementado (código):** existe la ruta y su controlador en `main`.
> - **Compila:** `npm run build` termina sin errores (en `catalog-service` requiere `npm run prisma:generate` previo).
> - **HTTP verificado:** se probó la solicitud real contra el servicio levantado (y su base de datos, cuando aplica). Ver sección 8.
> - **Pendiente / Propuesta:** no existe aún en `main`; se describe para acordar el contrato futuro.

---

## 1. Punto de entrada y configuración de red

### 1.1 API Gateway (`:3000`) — tráfico de autenticación y salud

El **API Gateway** (puerto `3000`) es la entrada prevista para los servicios de **Auth** (login mock y salud) y expone el healthcheck del propio gateway. Importante: **en el código de Mobile revisado, el flujo de login aún se simula en el cliente y no se envía al gateway** (ver sección 6.2); el endpoint y el proxy de Auth existen en el backend y quedan documentados aquí como contrato disponible para integrar ese flujo.

| Entorno / Plataforma | URL Base Gateway | Cómo se resuelve |
|---|---|---|
| Android Emulator | `http://10.0.2.2:3000/api/v1` | `ApiConfig.gatewayBaseUrl` por defecto |
| Web / Desktop / Local | `http://localhost:3000/api/v1` | `ApiConfig.gatewayBaseUrl` por defecto |
| Dispositivo físico (misma red) | `http://<IP-LAN-del-host>:3000/api/v1` | define vía `--dart-define` |
| Prioridad máxima | `--dart-define=API_GATEWAY_URL=...` | sección 7 |

### 1.2 Catalog y Material mediante el Gateway (#272)

`catalogApiClientProvider` y `materialApiClientProvider` reutilizan el cliente
central del Gateway. Las peticiones conservan `/api/v1/catalog` y
`/api/v1/materials`, respectivamente, sin acceder a puertos internos desde Mobile.

`DioMaterialListingRepository` implementa `MaterialListingRepository` (la parte
de lectura de `MaterialRepository`) y consume el contrato paginado disponible:
`GET /materials?page=1&pageSize=10` → `{ items, page, pageSize, total }`.
`PUBLISHED` se muestra como «Publicado». No envía búsqueda o filtros a Material.
Las demás operaciones abstractas de `MaterialRepository` se implementan en sus
tareas; no se agregaron métodos HTTP que fallen con `UnimplementedError`.

### 1.3 CORS y Swagger

- **CORS:** habilitado en api-gateway, auth-service, catalog-service y material-service (`app.enableCors()`), sin restricción de orígenes en desarrollo. `search-service` **no** llama a `enableCors()`, así que su `:3005` directo rechaza peticiones cross-origin; a través del gateway no aplica porque quien responde es el gateway.
- **Documentación OpenAPI:**
  - Índice de servicios: `http://<host>:3000/api/docs`
  - Spec del gateway (JSON): `http://<host>:3000/api/docs/gateway-json`
  - Auth Service: `http://localhost:3001/api/docs` · JSON `/api/docs-json`
  - Catalog Service: `http://localhost:3002/api/docs` · JSON `/api/docs-json`
  - Material Service: `http://localhost:3003/api/docs` · JSON `/api/docs-json`
  - Search Service: `http://localhost:3005/api/docs` · JSON `/api/docs-json`

---

## 2. Gateway → Auth: proxy HTTP

Implementado en `backend/api-gateway/src/modules/proxy/proxy.module.ts` (issue **#91**).

| Aspecto | Detalle |
|---|---|
| Rutas enviadas al proxy | `/api/v1/auth` y `/api/v1/auth/*` (métodos `ALL`) |
| Servicio destino | `AUTH_SERVICE_URL` (por defecto `http://127.0.0.1:3001`) |
| Variable de entorno | `AUTH_SERVICE_URL` — ver `backend/api-gateway/.env.example` |
| Timeout del proxy | `proxyTimeout: 5000` ms (configuración de `httpxy` mediante `serviceProxy`) |
| Reescritura de ruta | `/api/v1/auth/health` → `/api/v1/health` (el controlador de salud vive en `/health`) |
| Comportamiento adicional | `changeOrigin: true`; el cuerpo de POST se reenvía (`fixRequestBody`) |

**Respuesta cuando Auth no está disponible (502):** el proxy responde sin introducir el campo `error`, solo dos campos:

```json
{ "statusCode": 502, "message": "Auth Service no disponible" }
```

Verificado en vivo (sección 8): tanto `GET /api/v1/auth/health` como `POST /api/v1/auth/login` devuelven ese `502` cuando el auth-service está caído.

---

## 2b. Gateway → Material y Search: proxy HTTP

Implementado en `backend/api-gateway/src/modules/proxy/proxy.module.ts` (issue **#222**).

| Aspecto | Material | Search |
|---|---|---|
| Rutas enviadas al proxy | `/api/v1/materials` y `/api/v1/materials/*` (`ALL`) | `/api/v1/search` y `/api/v1/search/*` (`ALL`) |
| Servicio destino | `MATERIAL_SERVICE_URL` (por defecto `http://127.0.0.1:3003`) | `SEARCH_SERVICE_URL` (por defecto `http://127.0.0.1:3005`) |
| Timeout | 5 s | 5 s |
| Mensaje `502` | `Material Service no disponible` | `Search Service no disponible` |

Comparten el contrato ya verificado con Catalog: conservan método, query, cuerpo,
`Authorization` y cookies, y usan `fixRequestBody` para reenviar los cuerpos que
Nest ya procesó. No hay reescritura de ruta: el prefijo `/api/v1` se conserva tal
cual, lo que encaja con ambos servicios.

```json
{ "statusCode": 502, "message": "Material Service no disponible" }
{ "statusCode": 502, "message": "Search Service no disponible" }
```

**Cómo interpretar las respuestas hoy.** El `502` significa servicio caído, no
servicio incompleto. Con los servicios levantados:

| Petición | Respuesta | Motivo |
|---|---|---|
| `GET /api/v1/search?q=datos` | `200` con `results: []` | El endpoint existe pero la búsqueda desacoplada es un stub |
| `GET /api/v1/materials` | `200` con `items: []` | El listado paginado está implementado (#318); la base no tiene datos |
| `GET /api/v1/materials` con el servicio parado | `502` | Destino inalcanzable |

---

## 3. Endpoints implementados

### 3.1 `GET /api/v1/health` — Gateway

Salud del propio gateway. `200` → `{"status":"ok","service":"API Gateway","timestamp":"..."}`. **HTTP verificado.**

### 3.2 `GET /api/v1/auth/health` — vía proxy

Redirige a `/api/v1/health` de Auth (reescritura del proxy). `200` con `{"status":"ok",...}` si Auth está arriba; `502` (sección 2) si no. **Verificado solo el caso `502`** (sin base de datos de Auth en el entorno de elaboración).

### 3.3 `POST /api/v1/auth/login` — login mock temporal (issue #92)

> **Aclaración:** NO comprueba credenciales reales. Acepta cualquier correo y contraseña con formato válido y devuelve un **JWT simulado sin firma** solo para integración del frontend. El token **no sirve para autorizar** peticiones.

**Cuerpo de solicitud** (JSON):

| Campo | Tipo | Validación |
|---|---|---|
| `email` | string | debe ser un email válido |
| `password` | string | no vacía; debe contener al menos un carácter que no sea espacio en blanco |

**Respuesta `200`** (código HTTP 200, no 201):

```json
{
  "accessToken": "<b64(header).b64(payload).>",
  "tokenType": "Bearer",
  "expiresIn": 3600,
  "user": {
    "id": "00000000-0000-4000-8000-000000000092",
    "name": "Estudiante de prueba",
    "email": "estudiante@alu.uct.cl",
    "role": "STUDENT",
    "active": true
  }
}
```

El `accessToken` usa `alg: "none"` (payload con `mock: true`, `sub`, `email`, `role`, `iat`, `exp`) y no lleva firma.

**Errores `400`** (validación del DTO):

```json
{
  "statusCode": 400,
  "message": ["email must be an email", "password debe contener al menos un carácter que no sea espacio en blanco"],
  "error": "Bad Request"
}
```

**Estado:** código implementado en `main`, compila. **HTTP verificado solo el `502`** del proxy (sección 8); el `200` requiere el auth-service con su base de datos.

### 3.4 `GET /api/v1/catalog` — árbol del catálogo (directo a `:3002`)

Devuelve la jerarquía **Universidad → Carreras → Asignaturas** (universidades y carreras activas):

- **Universidad:** `id`, `name`, `code`, `active`, `careers[]`, `createdAt`, `updatedAt`
- **Carrera:** `id`, `name`, `code`, `active`, `subjects[]`, `createdAt`, `updatedAt`
- **Asignatura:** `id`, `name`, `code`, **`semester`** (semestre del plan de estudios; valor por defecto `1`), `active`, `createdAt`, `updatedAt`

> En el árbol las asignaturas se devuelven sin `description` ni `professors` (solo en `/filter`).
>
> **Precisión sobre `semester`:** el DTO de respuesta documenta en Swagger el rango `1–12`, pero el **máximo `12` no está impuesto** ni por el DTO de creación (en `create-subject` solo se exige `>= 1`) ni por el esquema de la base de datos (`Int @default(1)`). Se trata de una convención documentada en Swagger, no de una restricción garantizada. Ver también la sección de manejo de `semester` en `backend/catalog-service/README.md`.

**Ejemplo de respuesta `200`:**

```json
[
  {
    "id": "uuid-universidad",
    "name": "Universidad Católica de Temuco",
    "code": "UCT",
    "active": true,
    "createdAt": "2026-09-22T00:00:00.000Z",
    "updatedAt": "2026-09-22T00:00:00.000Z",
    "careers": [
      {
        "id": "uuid-carrera",
        "name": "Ingeniería Civil Informática",
        "code": "ICI",
        "active": true,
        "createdAt": "2026-09-22T00:00:00.000Z",
        "updatedAt": "2026-09-22T00:00:00.000Z",
        "subjects": [
          {
            "id": "uuid-asignatura",
            "name": "Programación II",
            "code": "PROG2",
            "semester": 3,
            "active": true,
            "createdAt": "2026-09-22T00:00:00.000Z",
            "updatedAt": "2026-09-22T00:00:00.000Z"
          }
        ]
      }
    ]
  }
]
```

**Estado:** código implementado en `main`, compila. **HTTP no verificado** (requiere la base de datos del catálogo).

### 3.5 `GET /api/v1/catalog/filter` — filtro jerárquico (directo a `:3002`)

**Parámetros de consulta** (todos opcionales):

| Parámetro | Tipo | Regla |
|---|---|---|
| `universityId` | UUID | Nivel 1. Sin requisito previo |
| `careerId` | UUID | Nivel 2. Requiere `universityId` |
| `subjectId` | UUID | Nivel 3. Requiere `careerId` |
| `professorId` | UUID | Nivel 4. Requiere `subjectId` |
| `year` | entero `2000–2100` | Nivel 5. Requiere `professorId` · § 501 |
| `type` | string | Nivel 6. Requiere `year` · § 501 |

**Orden obligatorio de niveles:** el filtrado es jerárquico; especificar un nivel sin su anterior devuelve `400`.

```json
{
  "statusCode": 400,
  "message": "Secuencia inválida: Para filtrar por Carrera (careerId) debe especificar Universidad (universityId).",
  "error": "Bad Request"
}
```

**Relaciones incluidas en cada asignatura devuelta:** `career` (con su `university`) y `professors`.

**`year`/`type` → `501 Not Implemented` solo si pasan las validaciones previas:** un parámetro mal formado (p. ej., `year` fuera de `2000–2100`) responde `400`, y una secuencia jerárquica incompleta (p. ej., `year` sin `professorId`) también responde `400`. Recién cuando el formato y la secuencia son válidos, solicitar año o tipo produce `501` (depende del módulo de Recursos, pendiente de integración):

```json
{
  "statusCode": 501,
  "message": "Los filtros por Año y Tipo requieren el módulo de Recursos (Resource), el cual está pendiente de integración en la base de datos.",
  "error": "Not Implemented"
}
```

**Ejemplo de respuesta `200` (con filtros de niveles 1–4):** asignatura con sus relaciones `career`, `career.university` y `professors`.

> **Ejemplo ilustrativo:** construido a partir del código (`Prisma SubjectWhereInput` con `include` de `career`/`university`/`professors`), no de una consulta ejecutada.

```json
[
  {
    "id": "uuid-asignatura",
    "name": "Programación II",
    "code": "PROG2",
    "semester": 3,
    "active": true,
    "createdAt": "2026-09-22T00:00:00.000Z",
    "updatedAt": "2026-09-22T00:00:00.000Z",
    "careerId": "uuid-carrera",
    "career": {
      "id": "uuid-carrera",
      "name": "Ingeniería Civil Informática",
      "code": "ICI",
      "active": true,
      "universityId": "uuid-universidad",
      "createdAt": "2026-09-22T00:00:00.000Z",
      "updatedAt": "2026-09-22T00:00:00.000Z",
      "university": {
        "id": "uuid-universidad",
        "name": "Universidad Católica de Temuco",
        "code": "UCT",
        "active": true,
        "createdAt": "2026-09-22T00:00:00.000Z",
        "updatedAt": "2026-09-22T00:00:00.000Z"
      }
    },
    "professors": [
      {
        "id": "uuid-profesor",
        "name": "Profesora Ana Pérez",
        "email": "ana.perez@uct.cl",
        "active": true,
        "createdAt": "2026-09-22T00:00:00.000Z",
        "updatedAt": "2026-09-22T00:00:00.000Z"
      }
    ]
  }
]
```

**Resultado vacío:** la combinación de filtros incompatibles (p. ej., `universityId` de una institución con `careerId` de otra) devuelve `[]`. Sin filtros devuelve la lista completa de asignaturas.

**Estado:** código implementado en `main`, compila. **HTTP no verificado** (requiere la base de datos del catálogo).

---

## 4. Pendiente vs. Propuesta (no disponible hoy)

| Elemento | Estado | Detalle |
|---|---|---|
| `POST /api/v1/auth/register` | **Pendiente/Propuesta** | No existe en `main` |
| `POST /api/v1/auth/refresh` | **Pendiente/Propuesta** | No existe en `main` |
| `POST /api/v1/auth/logout` | **Pendiente/Propuesta** | No existe en `main` |
| Recuperación de contraseña | **Pendiente/Propuesta** | Endpoints aún por definir |
| Autenticación real (JWT firmado y autorización) | **Pendiente** | El login actual es mock (sección 3.3); el esquema final es JWT Bearer |
| Paginación `page`/`limit` (`items`/`total`) | **Propuesta** | **No implementada** en los endpoints actuales de catálogo; si se requiere, debe proponerse y aprobarse el contrato |
| `year`/`type` en `/catalog/filter` | Pendiente | `501` solo si la secuencia es válida; depende del módulo de Recursos |
| Proxy Gateway → `/catalog` | Usado por Mobile (#272) | `CatalogRepository` usa el cliente central del Gateway; no consulta `:3002` directamente (sección 1.2) |
| Endpoints de Material | **Parcial** | `/api/v1/materials` está enrutada (#222) y `material-service` (#311) ya expone el listado paginado (#318, `200` con `items: []`); el detalle, la subida real y el preview siguen pendientes |
| Búsqueda en `/api/v1/search` | **Pendiente** | La ruta está enrutada (#222) y `search-service` existe (#305), pero `GET /api/v1/search?q=` devuelve un stub con `results: []` y `total: 0` |
| Proxy Gateway → `/quality` | **Pendiente** | El gateway no enruta `/api/v1/quality` y el servicio sigue siendo un placeholder |

---

## 5. Formato de errores

- Formato base NestJS: `{ statusCode, message, error }`.
- **`message` puede ser texto o lista:** los `BadRequestException` del código usan texto; los de `ValidationPipe` (p. ej., login) usan **lista** de mensajes (ver 3.3).
- **El `502` del proxy NO sigue el formato de 3 campos:** la respuesta es `{ statusCode, message }` (sin `error`). La guía de 3 campos `{ statusCode, message, error }` **no es universal**: cada servicio puede devolver y combinar sus respuestas.

---

## 6. Consumo real desde Mobile

### 6.1 Catálogo (conectado al backend)

- `CatalogRepository.getCatalog()` consulta `GET /catalog` mediante el cliente central, con **`ApiConfig.gatewayBaseUrl` (`:3000`)**. El Gateway reenvía la petición al servicio.
- Transforma el árbol (Universidad → Carreras → Asignaturas) en una **lista plana** de `CatalogItem` (`id`, `title` = asignatura, `author` = universidad, `subject` = carrera, `description`).
- La **búsqueda por texto ocurre en el cliente**: `getCatalog(search:)` filtra en memoria sobre `title`/`author`/`subject` (normaliza a minúsculas y compara con `contains`). Cada cambio del buscador dispara la consulta y el filtrado local.
- **Estados de interfaz** (`CatalogScreen`, with Riverpod `FutureProvider`):
  - **Carga:** `LoadingState` («Cargando catálogo…»).
  - **Resultados:** lista de tarjetas (`MaterialCard`).
  - **Vacío:** `EmptyState` («No se encontraron materiales») cuando la lista queda `[]`.
  - **Error + reintento:** `ErrorState` con botón que invalida el `FutureProvider` y vuelve a consultar.

### 6.2 Autenticación (todavía mock)

**Panorama del login por frontend en `main` (sin implementar ni corregir aquí, solo describir el estado):**

| Cliente | Estado |
|---|---|
| **Web** | Realiza solicitudes HTTP a `/auth/login` (login mock del backend). |
| **Mobile** | Simula el login localmente: la pantalla **sigue usando `MockAuthRepository`**; no envía la solicitud al gateway todavía. |
| **Backend** | Expone `POST /api/v1/auth/login` (mock, sección 3.3) que **no comprueba credenciales reales**; sirve para integrar el frontend. |

Detalles de la implementación actual de Mobile:

- La pantalla de login usa `MockAuthRepository` (`authRepositoryProvider` → `MockAuthRepository`): latencia simulada (~1 s), `password == 'error'` simula un `401`, `registrado@uct.cl` simula un `409` en registro.
- **Que exista `POST /api/v1/auth/login` en el backend no significa que la pantalla de Mobile lo consuma:** la integración HTTP de login no está conectada aún.
- **No hay renovación automática de tokens** en el cliente revisado (no hay flujo de refresh en el estado de sesión `AuthStateNotifier`).
- Estados de sesión vía Riverpod `AsyncValue` (loading / data / error), compartidos con la UI de login y registro.

---

## 7. Configuración de Mobile (`--dart-define`)

La única URL base es configurable en tiempo de compilación (ver `mobile/lib/core/config/api_config.dart`). Sin `--dart-define` se usan los valores por defecto según plataforma. **Los comandos se ejecutan desde `mobile/`.**

| Variable | Puerto por defecto | Rol |
|---|---|---|
| `API_GATEWAY_URL` | `:3000/api/v1` | Cliente central: Auth, salud, Catalog y listado de Material |

**Ejemplo — Android Emulator:**

```bash
flutter run \
  --dart-define=API_GATEWAY_URL=http://10.0.2.2:3000/api/v1
```

**Ejemplo — escritorio/local:**

```bash
flutter run \
  --dart-define=API_GATEWAY_URL=http://localhost:3000/api/v1
```

**Ejemplo — dispositivo físico (misma red, IP LAN del host, p. ej. `192.168.1.50`):**

```bash
flutter run \
  --dart-define=API_GATEWAY_URL=http://192.168.1.50:3000/api/v1
```

---

## 8. Comprobaciones reproducibles

**Preparación del entorno:** instalar dependencias y levantar PostgreSQL con la raíz del repo (ver `backend/README.md`). Para reproducir las pruebas de cada servicio, seguir los README específicos — no se duplican aquí todas las instrucciones, los enlaces permiten reproducir:

- `backend/auth-service/README.md` y `backend/catalog-service/README.md` cubren la **preparación de `.env`** (copiar `.env.example` y ajustar URLs/credenciales), la **aplicación de migraciones** (`prisma migrate deploy`), la **generación del cliente Prisma** (`npm run prisma:generate`) y el **inicio del servicio** en su puerto (auth `3001`, catalog `3002`).
- El catálogo además requiere el **seeding** de datos de prueba (script idempotente vía `upsert`, `npm run prisma:seed`; sección «Ejecución de Base de Datos y Seeding» de `backend/catalog-service/README.md`). Levantar PostgreSQL **no crea tablas ni carga datos** por sí solo.
- Puertos: gateway `3000`, auth `3001`, catalog `3002`.

**Solicitudes de ejemplo:**

```bash
# Login mock vía gateway (con auth-service arriba -> 200; caído -> 502)
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"estudiante@alu.uct.cl","password":"demo"}'

# Salud de Auth vía gateway
curl http://localhost:3000/api/v1/auth/health

# Árbol del catálogo (directo a :3002)
curl http://localhost:3002/api/v1/catalog

# Filtro del catálogo (directo a :3002)
curl "http://localhost:3002/api/v1/catalog/filter?universityId=<uuid>"
curl "http://localhost:3002/api/v1/catalog/filter?universityId=<uuid>&careerId=<uuid>"
```

**Registro de lo ejecutado en la elaboración de esta documentación** (rama actualizada a `7d80289`):

| Comprobación | Resultado |
|---|---|
| `npm run build` de `api-gateway`, `auth-service`, `catalog-service` | ✅ exit 0 (con caché purgada y `prisma:generate` en catálogo) |
| `oxlint` sobre archivos tocados | ✅ 0 errores |
| Gateway en vivo: `GET /api/v1/health` | ✅ `200` `{"status":"ok",...}` |
| Gateway en vivo: `GET /api/v1/auth/health` (auth caído) | ✅ `502` `{"statusCode":502,"message":"Auth Service no disponible"}` — verifica el proxy y su formato de error |
| Gateway en vivo: `POST /api/v1/auth/login` (auth caído) | ✅ `502` `{"statusCode":502,"message":"Auth Service no disponible"}` |
| Gateway en vivo: spec JSON `GET /api/docs/gateway-json` | ✅ `200` `application/json` |
| `POST /auth/login` → `200`, catálogo `/catalog` y `/catalog/filter` → `200/400/501`, salud de Auth → `200` | ⛔ **No verificado en vivo.** Requiere postgres (auth-db / catalog-db), no disponible en el entorno de elaboración. Los endpoints existen en `main`, compilan y quedan descritos desde su código. |

---

## 9. Referencias

- Checklist de integración de INT4: `docs/checklist-integracion-api-mobile.md` (actualizado en `main` con el estado real de los PRs #76, #91, #92, #97).
- Instrucciones de entorno y puertos: `backend/README.md`.
- Variables de entorno del gateway: `backend/api-gateway/.env.example`.
- Configuración de red de Mobile: `mobile/lib/core/config/api_config.dart`.
- Consumo de catálogo en Mobile: `mobile/lib/features/catalog/data/catalog_repository.dart` y `mobile/lib/features/catalog/presentation/screens/catalog_screen.dart`.
- `main` @ `7d80289` fue el commit de referencia de esta versión del documento.
