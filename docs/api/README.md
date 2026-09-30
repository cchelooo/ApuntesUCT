# Colección de API para Postman

Colección generada a partir del OpenAPI de los tres servicios del backend, para
probar la API sin escribir código.

| Archivo                               | Contenido                                                                                               |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| `apuntesuct.postman_collection.json`  | Colección Postman v2.1 con 11 peticiones agrupadas en `API Gateway`, `Auth Service` y `Catalog Service` |
| `apuntesuct.postman_environment.json` | Environment `ApuntesUCT local` con las URLs y variables                                                 |

## Importar

**Postman**: _Import_ → _Link, JSON or File_ → seleccionar ambos archivos.
Activa el environment `ApuntesUCT local` en la esquina superior derecha.

**Insomnia**: _Preferences → Data → Import Data_ → **Postman v2.1** →
seleccionar ambos archivos. Insomnia crea el environment y los request groups.

## Variables

| Variable                                | Valor por defecto       | Uso                                                                                                                                                                                                                                                                   |
| --------------------------------------- | ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `gatewayUrl`                            | `http://localhost:3000` | API Gateway (proxy de `/api/v1/auth` y `/api/v1/catalog`)                                                                                                                                                                                                             |
| `authUrl`                               | `http://localhost:3001` | Auth Service directo                                                                                                                                                                                                                                                  |
| `catalogUrl`                            | `http://localhost:3002` | Catalog Service directo                                                                                                                                                                                                                                               |
| `mockEmail`                             | `estudiante@alu.uct.cl` | Login mock: acepta cualquier correo válido                                                                                                                                                                                                                            |
| `mockPassword`                          | `demo`                  | Login mock: al menos un carácter no blanco                                                                                                                                                                                                                            |
| `accessToken`                           | _(vacío)_               | **No está en el environment a propósito.** Lo rellena el test del login y vive solo en la colección: en Postman la variable de environment tiene prioridad sobre la de colección, así que si estuviera aquí (vacía) taparía el token y se enviaría `Bearer ` sin nada |
| `universityId`, `careerId`, `subjectId` | UUID de ejemplo         | Sustituye por los ids reales de `GET /api/v1/catalog`                                                                                                                                                                                                                 |
| `professorId`                           | UUID de ejemplo         | **No** viene en `GET /api/v1/catalog`: obténlo de `GET /api/v1/catalog/filter` sin filtros, en el array `professors` de cada asignatura                                                                                                                               |
| `catalogYear`                           | `2026`                  | Parámetro `year` del filtro (responde `501`)                                                                                                                                                                                                                          |
| `catalogType`                           | `apunte`                | Parámetro `type` del filtro (responde `501`)                                                                                                                                                                                                                          |

## Requisitos para ejecutar las peticiones

- API Gateway: `cd backend/api-gateway && npm run start:dev` (no necesita base de datos).
- Auth Service y Catalog Service requieren su PostgreSQL (`db-auth`, `db-catalog`).
  El catálogo además arranca en el puerto `3002`: `PORT=3002 npm run start:dev`.
  Ver `backend/README.md`.
- Cada petición incluye un test que valida el código de estado esperado y que la
  respuesta es JSON.

## Particularidades de la API que la colección refleja

- **Login mock (#92)**: no verifica credenciales y devuelve un JWT sin firma
  (`alg: none`). No sirve para autorizar peticiones. Los dos peticiones de login
  (directo y vía gateway) usan `mockEmail`/`mockPassword` y su test guarda el
  `accessToken` de la respuesta en la variable `accessToken` de la colección.
- **Bearer**: las peticiones de catálogo (directas y vía gateway) llevan
  `Authorization: Bearer {{accessToken}}`. Hoy ningún endpoint lo valida; queda
  preparado para cuando exista autenticación real. Ejecuta primero una de las dos
  peticiones de login para que el token quede disponible: la variable
  `accessToken` se guarda **en la colección**, no en el environment, para que un
  valor vacío del environment no la sobrescriba.
- **Filtro del catálogo**: el orden jerárquico es obligatorio
  (`universityId` → `careerId` → `subjectId` → `professorId`); sin el orden
  completo responde `400 Bad Request`.
- **`professorId`**: `GET /api/v1/catalog` devuelve el árbol
  universidad → carrera → asignatura, **sin profesores**. Los UUID de profesor se
  obtienen de `GET /api/v1/catalog/filter` sin filtros, que responde las
  asignaturas con su array `professors`.
- **`year` y `type`**: responden `501 Not Implemented` porque dependen del módulo
  de Recursos. La colección incluye una petición para comprobarlos.
- **Rutas proxeadas**: el gateway enruta `/api/v1/auth` y `/api/v1/catalog` con
  middleware, así que no aparecen en su OpenAPI y el generador las añade
  explícitamente. Responden `502` si el servicio no responde. El gateway solo
  reescribe el health de Auth (`/api/v1/auth/health` → `/api/v1/health` en Auth);
  el healthcheck de Catalog está en `{{catalogUrl}}/api/v1/health`, sin
  equivalente vía gateway.
- **Parámetros del filtro**: todavía no están documentados en el OpenAPI del
  Catalog Service (a `FilterCatalogDto` le faltan los `@ApiProperty`), así que el
  generador los declara a mano. Al documentarlos en el DTO, la siguiente
  exportación los tomaré del spec.

## Regenerar la colección

Desde `backend/`:

```bash
npm run build
npm run export:postman
```

`export:postman` ejecuta `scripts/export-postman-collection.cjs`, que arranca
cada servicio con Prisma simulado (no necesita PostgreSQL), lee su documento
OpenAPI y escribe los dos JSON en `docs/api/`. Ejecuta `npm run build` antes,
porque el script usa el `dist` de cada servicio.
