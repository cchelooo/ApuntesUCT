# Backend — ApuntesUCT

Servicios backend del equipo INT2. Arquitectura de microservicios con API Gateway.

Tecnologías: Node.js, TypeScript, NestJS, Prisma, PostgreSQL, MinIO.

## Puertos locales de servicios

| Servicio | Puerto HTTP | URL local | Estado |
|---|---|---|---|
| api-gateway | 3000 | `http://localhost:3000` | Implementado |
| auth-service | 3001 | `http://localhost:3001` | Implementado |
| catalog-service | 3002 | `http://localhost:3002` | Implementado (PR #139 integrado en main) |
| material-service | 3003 | `http://localhost:3003` | Implementado (PR #311 integrado en main) |
| quality-service | 3004 (**) | `http://localhost:3004` | Pendiente (placeholder) |
| search-service | 3005 | `http://localhost:3005` | Implementado (PR #305 integrado en main) |

Catalog utiliza `3002` por defecto en su arranque, configuración interna y `.env.example`. Si existe un `.env` antiguo con otro valor, actualizarlo a `PORT=3002` para evitar conflictos. La variable `PORT` del proceso tiene prioridad sobre el archivo `.env`.

(**) Puerto propuesto/reservado para Quality. Todavía no hay un servicio disponible en esa dirección.

Notas:
- Los servicios implementados aplican el prefijo global `api/v1`. Gateway, Auth, Material y Search exponen `GET /api/v1/health`; Catalog excluye su health del prefijo y lo expone en `GET /health`.
- El api-gateway obtiene el puerto mediante `ConfigService` (`configService.get<number>('PORT') || 3000`), con `3000` como valor predeterminado. Expone `GET /api/v1/health` y un índice Swagger en `/api/docs`. Su módulo de proxy (`ProxyModule`) reenvía `/api/v1/auth` a Auth (`AUTH_SERVICE_URL`, por defecto `http://127.0.0.1:3001`; con reescritura de `/api/v1/auth/health` a `/api/v1/health`), `/api/v1/catalog` a Catalog (`CATALOG_SERVICE_URL`, `http://127.0.0.1:3002`), `/api/v1/materials` a Material (`MATERIAL_SERVICE_URL`, `http://127.0.0.1:3003`) y `/api/v1/search` a Search (`SEARCH_SERVICE_URL`, `http://127.0.0.1:3005`), todas con timeout de 5 s y `502` con un mensaje propio de cada servicio cuando el destino no responde. Quality todavía no se enruta. Ver `api-gateway/README.md`.
- Cobertura real de los destinos: Catalog expone el árbol y el filtrado en `/api/v1/catalog`; Material atiende `GET /api/v1/materials` con el listado paginado (`{ items, page, pageSize, total }`, vacío si la base no tiene datos) y `POST /api/v1/materials` como stub; y Search atiende `GET /api/v1/search` (devuelve un stub con `results: []`; la búsqueda desacoplada es trabajo en curso). El `502` del gateway corresponde al servicio caído.
- Documentación Swagger por servicio: API Gateway en `http://localhost:3000/api/docs/gateway` (spec JSON en `/api/docs/gateway-json`); Auth, Catalog, Material y Search en `http://localhost:<puerto>/api/docs` con spec JSON en `/api/docs-json` (puertos 3001, 3002, 3003 y 3005).
- CORS: habilitado en api-gateway, auth-service, catalog-service y material-service (`app.enableCors()`). Search no llama a `enableCors()`, así que el acceso cross-origin a `:3005` directo está restringido; a través del gateway no aplica. Sin restricción de orígenes en desarrollo: los servicios aceptan solicitudes cross-origin (front web y app mobile).
- Requisitos para levantarlos: material-service necesita su base `material_db` (`db_material`, puerto `5436`); search-service no usa base de datos.

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

Instalar una sola vez desde la raíz del workspace (se usa `backend/package-lock.json`):

```bash
cd backend
npm ci
npm run prisma:generate
```

Los comandos siguientes parten de la raíz del repositorio en terminales separadas.
Los clientes de Prisma de auth, catálogo y materiales se generan por separado;
no comparten el cliente predeterminado de `@prisma/client`.

2. API Gateway (no requiere base de datos):

```bash
cd backend/api-gateway
npm run start:dev
```

3. Auth Service (requiere PostgreSQL disponible para arrancar):

```bash
cd backend/auth-service
[ ! -f .env ] && cp .env.example .env   # solo si .env no existe aún
npm run prisma:generate
npm run start:dev
```

Asegurarse de que `DATABASE_URL` del `.env` coincida con el PostgreSQL local (definido en `docker-compose.yml`).

4. Catalog Service (usa el puerto 3002 para no colisionar con gateway y auth):

```bash
cd backend/catalog-service
[ ! -f .env ] && cp .env.example .env   # solo si .env no existe aún
npm run prisma:generate
PORT=3002 npm run start:dev
```

Alternativa en Windows PowerShell (con preparación de `.env` y Prisma):

```powershell
cd backend/catalog-service
if (-Not (Test-Path .env)) { Copy-Item .env.example .env }
npm run prisma:generate
$env:PORT=3002
npm run start:dev
```

5. Material Service (requiere `db-material` de Docker Compose):

```bash
cd backend
npm ci
[ ! -f material-service/.env ] && cp material-service/.env.example material-service/.env
npm run prisma:generate --workspace=material-service
npm run prisma:deploy --workspace=material-service
npm run start:dev --workspace=material-service
```

Usa `3003` por defecto; `PORT` permite cambiarlo. Ver [Material Service](material-service/README.md) para compilación, arranque de producción y pruebas.

## Verificación

La base de las rutas HTTP es `http://localhost:<puerto>/api/v1` y la documentación Swagger está en `http://localhost:<puerto>/api/docs` para cada servicio.

Comprobar el healthcheck de los servicios implementados:

```bash
curl http://localhost:3000/api/v1/health
curl http://localhost:3001/api/v1/health
curl http://localhost:3002/health
curl http://localhost:3003/api/v1/health
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
`auth-service`, `catalog-service` y `material-service`. No requiere PostgreSQL ni Docker en ejecución:
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

# Cobertura de los servicios
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


### Casos críticos de autenticación (#115)

Las pruebas unitarias de `auth-service/src/presentation/auth/` cubren:

- El contrato de sesión y la normalización del correo.
- Los claims del JWT mock, su marca de simulación y su vigencia de una hora,
  usando un reloj fijo para que la prueba sea determinista.
- La ausencia de contraseñas en la respuesta y en el token decodificado.
- El rechazo de correos inválidos y contraseñas ausentes, de tipo incorrecto
  o compuestas únicamente por espacios en blanco.
- La eliminación de campos no permitidos mediante `ValidationPipe` y la
  imposibilidad de sobrescribir la identidad o el rol simulado desde el cuerpo.

Para ejecutar solo estos casos desde `backend/`:

```bash
npm test --workspace=auth-service -- --runInBand --testPathPatterns=presentation/auth
```

Estas pruebas no necesitan HTTP, PostgreSQL ni servicios externos. El login
actual es un mock: no verifica usuarios ni contraseñas y emite un JWT sin firma.
La verificación de credenciales, la firma y validación de tokens, la renovación
y la revocación de sesiones requieren pruebas cuando se implementen esos flujos.

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
| Alcance parcial de Material y Search | El gateway enruta `/api/v1/materials` y `/api/v1/search` a servicios ya integrados en main (Material #311 + listado #318; Search #305). Con ambos arriba, `/api/v1/materials` devuelve `200` con el listado paginado y `POST /api/v1/materials` es un stub; `/api/v1/search` devuelve `200` con un stub `results: []`. El `502` del gateway solo aparece cuando el destino está caído | `api-gateway/README.md` |
| El gateway no enruta Quality | `/api/v1/quality` no pasa por el gateway; el servicio es un placeholder sin implementación | `api-gateway/README.md` |
| Health de Catalog no enrutado por el gateway | `/api/v1/catalog/health` devuelve `404` porque Catalog excluye `health` del prefijo global; su health real es `http://localhost:3002/health` | `catalog-service/src/main.ts` |
| Registro por el gateway | `/api/v1/auth/register` devuelve `404` hasta que se implemente el endpoint | `api-gateway/README.md` |
| Filtros `year` y `type` del catálogo | Devuelven `501 Not Implemented`; dependen del módulo de Recursos | `catalog-service` (Swagger `http://localhost:3002/api/docs`) |
| Paginación del catálogo | Los endpoints no implementan `page`/`limit` (propuesto, no implementado) | `docs/mobile/integracion-api-mobile.md` |
| Autenticación en Mobile | El login ya consume el gateway mediante `DioAuthRepository`. `MockAuthRepository` queda para el modo demo (`--dart-define=AUTH_DEMO_MODE=true`) y como fallback de las operaciones que el backend aún no expone, como registro y logout | `mobile/lib/features/auth/data/` |
| Swagger por servicio | Cada microservicio expone su propia especificación; no hay una spec unificada del ecosistema | índice `/api/docs` del gateway |

### Ejecución de pruebas en catalog.http

## Requisitos para funcionamiento

* Extensión **REST Client** en VSC

* Tener levantados los contenedores Docker del proyecto
```bash
  docker compose up -d
```

**Base de Datos Migrada y Poblada (Seed):**
* Es imprescindible contar con la estructura de tablas y los datos base (Universidades, Carreras, Asignaturas) precargados en catalog-service, para ello ejecutar dentro de catalog-service:

```bash
  npx prisma migrate dev
  npx prisma db seed
```

* Tener corriendo la aplicación o los microservicios necesarios (`api-gateway` en el puerto `3000` y `catalog-service` en el puerto `3002`) mediante 2 terminales separadas cada una corriendo 1 de los servicios usando dentro de su respectiva carpeta del microservicio:

```bash
  npm run start: dev
```

## Para levantar los servicios

* Moverse a cada microservicio en su respectiva terminal dedicada y ejecutar:

```bash
  npm run start:dev
```

## Una vez corriendo los 2 servicios:

# Obtención de IDs para las variables
1. Ejecutar **1.1** (`GET /catalog`) para obtener `@universityId`, `@careerId` y `@subjectId`.
2. Ejecutar **1.2a** (`GET /catalog/filter`) para buscar la asignatura seleccionada y copiar el ID de uno de sus profesores en `@professorId` y sus respectivos UUIDs de `@universityId`, `@careerId` y `@subjectId` relacionados con el profesor.

## Verificaciones Manuales Esperadas
- **Campo `semester`:** En **1.1 / 1.1b**, verificar que cada asignatura contenga la propiedad `semester`.
- **Datos de Creación:** En **2.3**, verificar que el objeto devuelto en la respuesta `201 Created` coincida en `name`, `code`, `semester` y `careerId` con el cuerpo enviado.
