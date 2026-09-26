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

(*) Puerto para ejecución local, no un valor predeterminado del servicio. El catálogo, tal como está en main, no levanta en 3002 por sí solo: su `.env.example` define `PORT=3001` (que coincide con auth-service) y `src/main.ts` usa `3000` cuando no existe `PORT` (que coincide con api-gateway). Ejecutarlo con `PORT=3002 npm run start:dev` evita ambos conflictos; esa variable tiene prioridad sobre el valor del `.env` durante esa ejecución.

(**) Puertos propuestos/reservados para Material, Quality y Search. Todavía no hay servicios disponibles en esas direcciones.

Notas:
- Los servicios implementados aplican el prefijo global `api/v1` y cada uno expone su healthcheck `GET /api/v1/health` (api-gateway, auth-service y catalog-service).
- El api-gateway obtiene el puerto mediante `ConfigService` (`configService.get<number>('PORT') || 3000`), con `3000` como valor predeterminado. Expone `GET /api/v1/health` y un índice Swagger en `/api/docs`. Su módulo de proxy (`ProxyModule`) reenvía `/api/v1/auth` y sus subrutas a Auth (`AUTH_SERVICE_URL`, por defecto `http://127.0.0.1:3001`; timeout de 5 s; si Auth no responde devuelve `502` con `Auth Service no disponible`). El resto de microservicios no se enrutan por el gateway todavía. Ver `api-gateway/README.md`.
- Documentación Swagger por servicio: API Gateway en `http://localhost:3000/api/docs/gateway` (spec JSON en `/api/docs/gateway-json`); Auth y Catalog en `http://localhost:<puerto>/api/docs` con spec JSON en `/api/docs-json` (puertos 3001 y 3002).
- CORS: habilitado en api-gateway, auth-service y catalog-service (`app.enableCors()`). Sin restricción de orígenes en desarrollo: los servicios aceptan solicitudes cross-origin (front web y app mobile).

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

## Deuda técnica

Registro de la deuda conocida del backend. La mayoría corresponde a decisiones de
las primeras etapas (Sprint 1) para integrar a los equipos de producto; se deja
constancia explícita para priorizar su cierre antes de producción.

### JWT mock del login (#92)

- `POST /api/v1/auth/login` acepta cualquier correo con formato válido y una
  contraseña con al menos un carácter no blanco: **no verifica credenciales** ni
  exige dominio institucional.
- Devuelve un **JWT sin firma** (`alg: none`, `mock: true`, firma vacía) con un
  usuario ficticio de UUID fijo, `expiresIn: 3600` y **sin refresh token**.
- **El token no autoriza peticiones**: es solo para integrar los frontends y no
  debe aceptarse en flujos protegidos ni validarse como sesión real.
- Pendiente: autenticación real (hash y verificación de credenciales, emisión de
  JWT firmado), registro de usuarios, cierre de sesión y renovación de tokens.
  El modelo de usuarios (#51/#52) ya está persistido, pero el endpoint no lo usa.
- Detalle y ejemplo en `auth-service/README.md` → «Login mock (#92)».

### Resto de la deuda conocida

| Deuda | Descripción | Referencia |
| --- | --- | --- |
| El gateway enruta solo Auth | `/catalog`, `/material`, `/quality` y `/search` no pasan por el gateway; Mobile consulta el catálogo directo en `:3002` | `api-gateway/README.md` |
| Registro por el gateway | `/api/v1/auth/register` devuelve `404` hasta que se implemente el endpoint | `api-gateway/README.md` |
| Filtros `year` y `type` del catálogo | Devuelven `501 Not Implemented`; dependen del módulo de Recursos | `catalog-service` (Swagger y `docs/mobile/integracion-api-mobile.md`) |
| Paginación del catálogo | Los endpoints no implementan `page`/`limit` (propuesto, no implementado) | `docs/mobile/integracion-api-mobile.md` |
| Autenticación en Mobile | La pantalla de login de la app sigue usando `MockAuthRepository` (simulado en cliente) pese a que el backend expone el login HTTP mock | `mobile/` |
| Swagger por servicio | Cada microservicio expone su propia especificación; no hay una spec unificada del ecosistema | índice `/api/docs` del gateway |