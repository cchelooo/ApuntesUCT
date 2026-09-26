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
- El api-gateway obtiene el puerto mediante `ConfigService` (`configService.get<number>('PORT') || 3000`), con `3000` como valor predeterminado. Expone `GET /api/v1/health` y Swagger en `/api/docs`. Su módulo de proxy todavía está vacío, por lo que aún no enruta peticiones hacia los servicios.
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


## Paso a paso para ejecución de pruebas del backend

Base de Datos PostgreSQL (Requerida para auth-service y catalog-service):

Asegurar que el contenedor o servicio local de PostgreSQL esté arriba (puertos 5432 o 5433).

Verificar la variable DATABASE_URL en cada archivo .env.

# Preparación de Esquemas de Prisma

# En backend/auth-service
npx prisma db push

# En backend/catalog-service
npx prisma migrate dev
npx prisma db seed

## Clasificacion Tests E2E de microservicios

# -----------------------------------------------------------------------------------------------------------------

# Microservicio                       Tipo de Prueba                         Requeiere BD Real?             

api-gateway                       Proxy e Integración Mock                NO(Usa servidores simulados)

auth-service                   Endpoints, HTTP y Persistencia               SI(PostgreSQL/Prisma)

catalog-service             Endpoints, HTTP, Filtros y Migraciones          SI(PostgreSQL/Prisma)

# -----------------------------------------------------------------------------------------------------------------

# Comando para ejecutar las pruebas (Dentro de cada microservicio)

```bash
   npm run test:e2e
```



## Pruebas unitarias con Jest

Desde la raíz del repositorio, con Node.js 22 y npm:

```bash
cd backend
npm ci
npm test
```

`npm test` genera los clientes Prisma y ejecuta las pruebas de `api-gateway`,
`auth-service` y `catalog-service`. No requiere PostgreSQL ni Docker en ejecución:
las pruebas unitarias simulan sus dependencias externas. La generación de Prisma
puede necesitar descargar sus binarios en la primera instalación.

La configuración común está en `jest.config.base.cjs`; cada servicio la extiende
con su propio `jest.config.cjs`. Jest usa el entorno Node y `ts-jest` para transformar
TypeScript con el `tsconfig.json` de cada servicio, incluidos los decoradores de
NestJS. Busca únicamente archivos `src/**/*.spec.ts`. Antes de cada prueba limpia
el historial de los mocks y restaura los métodos reemplazados mediante `jest.spyOn`.

Comandos desde `backend/`:

```bash
# Todas las pruebas, en serie dentro de cada servicio
npm test -- --runInBand

# Ejecución para CI, sin modo interactivo
npm run test:ci

# Cobertura de los tres servicios
npm run test:cov -- --runInBand

# Un único servicio (generar antes los clientes Prisma)
npm run prisma:generate
npm test --workspace=auth-service -- --runInBand

# Modo watch de un servicio
npm run test:watch --workspace=catalog-service
```

La cobertura se guarda en `backend/<servicio>/coverage/`, con resumen en terminal,
reporte HTML (`index.html`) y LCOV (`lcov.info`). Excluye los archivos de pruebas,
declaraciones de tipos, módulos de NestJS y el arranque `main.ts`. Los reportes
están ignorados por Git; no se impone todavía un porcentaje mínimo de cobertura.

Para agregar una prueba, crea un archivo `*.spec.ts` junto al código que verifica
y usa `@nestjs/testing` con mocks para las dependencias externas. Hay ejemplos en
`catalog-service/src/application/services/catalog.service.spec.ts` y en los
controladores de health de cada servicio.

Las pruebas E2E de `test/` mantienen su configuración independiente y se ejecutan
con `npm run test:e2e --workspace=<servicio>`; pueden requerir base de datos u otros
servicios según la prueba. Los servicios placeholder no forman parte de los
workspaces ni de esta ejecución.
