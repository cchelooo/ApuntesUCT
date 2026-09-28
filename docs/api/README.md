# Colección de API para Postman

Colección generada a partir del OpenAPI de los tres servicios del backend, para
probar la API sin escribir código.

| Archivo                               | Contenido                                                                                              |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `apuntesuct.postman_collection.json`  | Colección Postman v2.1 con 9 peticiones agrupadas en `API Gateway`, `Auth Service` y `Catalog Service` |
| `apuntesuct.postman_environment.json` | Environment `ApuntesUCT local` con las URLs y variables                                                |

## Importar

**Postman**: _Import_ → _Link, JSON or File_ → seleccionar ambos archivos.
Activa el environment `ApuntesUCT local` en la esquina superior derecha.

**Insomnia**: _Preferences → Data → Import Data_ → **Postman v2.1** →
seleccionar ambos archivos. Insomnia crea el environment y los request groups.

## Variables

| Variable                                               | Valor por defecto       | Uso                                                   |
| ------------------------------------------------------ | ----------------------- | ----------------------------------------------------- |
| `gatewayUrl`                                           | `http://localhost:3000` | API Gateway (proxy de `/api/v1/auth`)                 |
| `authUrl`                                              | `http://localhost:3001` | Auth Service directo                                  |
| `catalogUrl`                                           | `http://localhost:3002` | Catalog Service directo                               |
| `mockEmail`                                            | `estudiante@alu.uct.cl` | Login mock: acepta cualquier correo válido            |
| `mockPassword`                                         | `demo`                  | Login mock: al menos un carácter no blanco            |
| `universityId`, `careerId`, `subjectId`, `professorId` | UUID de ejemplo         | Sustituye por los ids reales de `GET /api/v1/catalog` |
| `catalogYear`                                          | `2026`                  | Parámetro `year` del filtro (responde `501`)          |
| `catalogType`                                          | `apunte`                | Parámetro `type` del filtro (responde `501`)          |

## Requisitos para ejecutar las peticiones

- API Gateway: `cd backend/api-gateway && npm run start:dev` (no necesita base de datos).
- Auth Service y Catalog Service requieren su PostgreSQL (`db-auth`, `db-catalog`).
  El catálogo además arranca en el puerto `3002`: `PORT=3002 npm run start:dev`.
  Ver `backend/README.md`.
- Cada petición incluye un test que valida el código de estado esperado y que la
  respuesta es JSON.

## Particularidades de la API que la colección refleja

- **Login mock (#92)**: no verifica credenciales y devuelve un JWT sin firma
  (`alg: none`). No sirve para autorizar peticiones.
- **Filtro del catálogo**: el orden jerárquico es obligatorio
  (`universityId` → `careerId` → `subjectId` → `professorId`); sin el orden
  completo responde `400 Bad Request`.
- **`year` y `type`**: responden `501 Not Implemented` porque dependen del módulo
  de Recursos. La colección incluye una petición para comprobarlos.
- **Rutas proxeadas**: `/api/v1/auth/health` y `/api/v1/auth/login` a través del
  gateway no aparecen en el OpenAPI del gateway (el proxy es middleware), por lo
  que el generador las añade explícitamente. Responden `502` si Auth no está
  disponible.
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
