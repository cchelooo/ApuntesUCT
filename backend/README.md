# Backend — ApuntesUCT

Servicios backend del equipo INT2. Arquitectura de microservicios con API Gateway.

Tecnologías: Node.js, TypeScript, NestJS, Prisma, PostgreSQL, MinIO.

## Puertos locales de servicios

| Servicio | Puerto HTTP | URL local | Estado |
|---|---|---|---|
| api-gateway | 3000 | `http://localhost:3000` | Implementado |
| auth-service | 3001 | `http://localhost:3001` | Implementado |
| catalog-service | 3002 (*) | `http://localhost:3002` | Implementado (PR #139 integrado en main) |
| material-service | 3003 (**) | `http://localhost:3003` | Pendiente (placeholder) |
| quality-service | 3004 (**) | `http://localhost:3004` | Pendiente (placeholder) |
| search-service | 3005 (**) | `http://localhost:3005` | Pendiente (placeholder) |

(*) Puerto para ejecución local. Tras la alineación del PR #76, el catálogo corre por defecto en `3002`: su `.env.example` define `PORT=3002` y `src/main.ts` usa `process.env.PORT ?? 3002`. Así evita colisionar con api-gateway (3000) y auth-service (3001).

(**) Puertos propuestos/reservados para Material, Quality y Search. Todavía no hay servicios disponibles en esas direcciones.

Notas:
- Los servicios implementados aplican el prefijo global `api/v1` y cada uno expone su healthcheck `GET /api/v1/health` (api-gateway, auth-service y catalog-service).
- El api-gateway obtiene el puerto mediante `ConfigService` (`configService.get<number>('PORT') || 3000`), con `3000` como valor predeterminado. Expone `GET /api/v1/health` y Swagger en `/api/docs`. Su módulo de proxy todavía está vacío, por lo que aún no enruta peticiones hacia los servicios.
- Documentación Swagger por servicio: `http://localhost:<puerto>/api/docs` (api-gateway, auth-service y catalog-service).

## Puertos de bases de datos (docker-compose.yml)

| Contenedor | Puerto host | Base de datos |
|---|---|---|
| `db_auth` | 5432 | `auth_db` |
| `db_catalog` | 5433 | `catalog_db` |
| `db_quality` | 5434 | `quality_db` |
| `db_search` | 5435 | `search_db` |
| `db_material` | 5436 | `material_db` |
| `apuntes_minio` (API S3) | 9000 | — |
| `apuntes_minio` (consola) | 9001 | — |

Credenciales comunes: `uct_admin` / `uct_password_123`.

## Comandos de ejecución local

Requisitos: **Node.js 22**, **npm** y **Docker Compose**.

Cada bloque a continuación se ejecuta en una **terminal independiente**, siempre comenzando desde la **raíz del repositorio**.

1. Levantar las dependencias de infraestructura (PostgreSQL + MinIO):

```bash
docker compose up -d
```

Detener las dependencias:

```bash
docker compose down
```

2. API Gateway (no requiere base de datos):

```bash
cd backend/api-gateway
npm install
npm run start:dev
```

3. Auth Service (requiere PostgreSQL disponible para arrancar):

```bash
cd backend/auth-service
npm install
[ ! -f .env ] && cp .env.example .env   # solo si .env no existe aún
npm run prisma:generate
npm run start:dev
```

Asegurarse de que `DATABASE_URL` del `.env` coincida con el PostgreSQL local (definido en `docker-compose.yml`).

4. Catalog Service (usa el puerto 3002 para no colisionar con gateway y auth):

```bash
cd backend/catalog-service
npm install
[ ! -f .env ] && cp .env.example .env   # solo si .env no existe aún
npm run prisma:generate
PORT=3002 npm run start:dev
```

Alternativa en Windows PowerShell (con preparación de `.env` y Prisma):

```powershell
cd backend/catalog-service
npm install
if (-Not (Test-Path .env)) { Copy-Item .env.example .env }
npm run prisma:generate
$env:PORT=3002
npm run start:dev
```

## Verificación

La base de las rutas HTTP es `http://localhost:<puerto>/api/v1` y la documentación Swagger está en `http://localhost:<puerto>/api/docs` para cada servicio.

Comprobar el healthcheck de los tres servicios implementados:

```bash
curl http://localhost:3000/api/v1/health
curl http://localhost:3001/api/v1/health
curl http://localhost:3002/api/v1/health
```

Cada uno debe responder `200 OK` con `{"status":"ok",...}` mientras su servicio esté corriendo.