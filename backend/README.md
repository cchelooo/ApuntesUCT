# Backend — ApuntesUCT

Servicios backend del equipo INT2. Arquitectura de microservicios con API Gateway.

Tecnologías: Node.js, TypeScript, NestJS, Prisma, PostgreSQL, MinIO.

## Puertos locales de servicios

| Servicio | Puerto HTTP | URL local | Estado |
|---|---|---|---|
| api-gateway | 3000 | `http://localhost:3000` | Pendiente (placeholder) |
| auth-service | 3001 | `http://localhost:3001` | Implementado |
| catalog-service | 3002 | `http://localhost:3002` | Cascarón (PR #139) |
| material-service | 3003 | `http://localhost:3003` | Pendiente (placeholder) |
| quality-service | 3004 | `http://localhost:3004` | Pendiente (placeholder) |
| search-service | 3005 | `http://localhost:3005` | Pendiente (placeholder) |

Notas:
- Los servicios aplican el prefijo global `api/v1`. El único endpoint implementado hoy es `GET /api/v1/health` de auth-service.
- Swagger del auth-service: `http://localhost:3001/api/docs`.
- El cascarón del catalog-service (rama `feature/21-cascaron-catalog-service`, PR #139) usa provisionalmente el puerto 3001; al integrarse debe pasarse a **3002** para no colisionar con auth-service.

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

Auth service (único implementado):

```bash
cd backend/auth-service
npm install
npm run prisma:generate
npm run start:dev
```

La API queda en `http://localhost:3001` y la documentación Swagger en `http://localhost:3001/api/docs`.