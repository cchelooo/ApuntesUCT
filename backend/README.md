# Backend — ApuntesUCT

Servicios backend del equipo INT2. Arquitectura de microservicios con API Gateway.

Tecnologías: Node.js, TypeScript, NestJS, Prisma, PostgreSQL, MinIO.

## Puertos locales de servicios

| Servicio | Puerto HTTP | URL local | Estado |
|---|---|---|---|
| api-gateway | 3000 | `http://localhost:3000` | Implementado |
| auth-service | 3001 | `http://localhost:3001` | Implementado |
| catalog-service | 3002 (*) | `http://localhost:3002` | Implementado (PR #139 integrado en main) |
| material-service | 3003 | `http://localhost:3003` | Pendiente (placeholder) |
| quality-service | 3004 | `http://localhost:3004` | Pendiente (placeholder) |
| search-service | 3005 | `http://localhost:3005` | Pendiente (placeholder) |

(*) El catálogo, tal como está en main, no levanta en 3002 por sí solo: `src/main.ts` usa el puerto `3000` por defecto (`process.env.PORT ?? 3000`) y su `.env.example` define `PORT=3001`. Ambos valores colisionan con api-gateway (3000) y auth-service (3001), por lo que hay que ejecutarlo con `PORT=3002` para correrlo en paralelo con los demás servicios.

Notas:
- Los servicios implementados aplican el prefijo global `api/v1` y cada uno expone su healthcheck `GET /api/v1/health` (api-gateway, auth-service y catalog-service).
- El api-gateway usa por defecto el puerto `3000` (`process.env.PORT || 3000`) y enruta las peticiones `api/v1` hacia los servicios.
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

Dependencias de infraestructura (PostgreSQL + MinIO) desde la raíz del repo:

```bash
docker compose up -d
```

Detener las dependencias:

```bash
docker compose down
```

Servicios implementados (los tres están en main):

API Gateway:

```bash
cd backend/api-gateway
npm install
npm run start:dev
```

Auth Service:

```bash
cd backend/auth-service
npm install
npm run prisma:generate
npm run start:dev
```

Catalog Service (usa el puerto 3002 para no colisionar con gateway y auth):

```bash
cd backend/catalog-service
npm install
PORT=3002 npm run start:dev
```

En Windows PowerShell se debe definir la variable de entorno con `$env:PORT=3002` antes del comando:

```powershell
cd backend/catalog-service
$env:PORT=3002
npm run start:dev
```

La API queda en `http://localhost:<puerto>` y la documentación Swagger en `http://localhost:<puerto>/api/docs` para cada servicio.