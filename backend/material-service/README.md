# Material Service

Microservicio NestJS de materiales académicos con persistencia Prisma (#217).
Requiere Node.js 22, npm y PostgreSQL. Usa `db-material` de Docker Compose
(contenedor `db_material`, base `material_db`, puerto local `5436`).
MinIO todavía no es necesario para ejecutar el servicio.

## Instalación y ejecución

Desde la raíz del repositorio:

```bash
docker compose up -d db-material
cd backend
npm ci
cp material-service/.env.example material-service/.env # solo si no existe
npm run prisma:generate --workspace=material-service
npm run prisma:deploy --workspace=material-service
npm run start:dev --workspace=material-service
```

`PORT` es opcional y vale `3003` por defecto. El archivo `.env` se carga desde
el directorio del servicio al usar los scripts del workspace. Las variables del
proceso tienen prioridad sobre el archivo. Si ya existe `.env`, agregar
`DATABASE_URL` siguiendo `.env.example`. Desde otro contenedor de la red Compose,
usar `db-material:5432` en lugar de `localhost:5436`.
El arranque establece la conexión a PostgreSQL y falla si no puede conectarse;
el cliente se desconecta al destruir el módulo NestJS.

Para compilar y ejecutar en producción, desde `backend/`:

```bash
npm run prisma:generate --workspace=material-service
npm run build --workspace=material-service
npm run start:prod --workspace=material-service
```

La compilación genera `dist/main.js`. También se puede ejecutar `npm run start
--workspace=material-service` para compilar y levantar sin watch.

## Endpoints

| Endpoint | Propósito |
| --- | --- |
| `GET http://localhost:3003/api/v1/health` | Estado del proceso |
| `GET http://localhost:3003/api/docs` | Swagger UI |
| `GET http://localhost:3003/api/docs-json` | Especificación OpenAPI |

El healthcheck responde `200` con `status: "ok"`, `service: "material-service"`
y `timestamp` en formato ISO. No comprueba dependencias externas.
Las rutas de la API usan el prefijo `api/v1`; Swagger queda en `api/docs`.
CORS está habilitado siguiendo los demás servicios del backend.

## Estructura

- `src/presentation`: controladores HTTP y módulos de entrada.
- `src/application`: servicios de aplicación, incluido el healthcheck.
- `src/domain`: espacio para las futuras entidades y reglas de materiales.
- `src/infrastructure`: configuración y módulo de conexión Prisma.
- `prisma/schema.prisma`: modelos de persistencia propios del servicio.
- `prisma/migrations`: historial SQL reproducible.

## Persistencia y límites del dominio

El esquema sigue el MER de Material en `docs/diagrams/int4/diagrama_mer_material.png`:

- `MaterialType`: clasificación local por nombre único y estado activo.
- `Material`: metadatos, año académico, estado y referencias lógicas externas.
  El estado inicial es `PENDING_REVIEW`; también contempla `PUBLISHED`, `REJECTED`
  y `WITHDRAWN`. La marca `verified` comienza en `false`.
- `MaterialVersion`: número de versión, clave de almacenamiento, nombre original,
  MIME, tamaño en bytes (`BigInt`), checksum, autor y fecha de creación.
  `(materialId, versionNumber)` es único: cada material conserva su propio historial.

Las únicas relaciones SQL son `Material → MaterialType` y
`MaterialVersion → Material`. Ambas usan `RESTRICT` al eliminar para proteger
los materiales y su historial. La validación de metadatos, la asignación del
siguiente número de versión y las transiciones de estado corresponden a los
futuros casos de uso; este esquema no los implementa.

`uploaderId` y `createdBy` son UUID lógicos de Auth. `subjectId`, `professorId`,
`universityId`, `careerId` y `academicOfferingId` son identificadores lógicos de
Catalog (texto, compatible con sus IDs actuales). No existen modelos User,
Subject ni Professor ni claves foráneas hacia sus bases. Universidad, carrera,
profesor y oferta académica son opcionales; asignatura es obligatoria.
La comprobación de referencias externas corresponde a futuros servicios de aplicación.

El cliente se genera en `material-service/node_modules/.prisma/material-client`
y se importa desde `.prisma/material-client`. Así no sobrescribe el cliente de
Auth o Catalog al generar todos los workspaces. No se versiona el código generado;
se debe regenerar después de `npm ci` y antes de compilar o ejecutar pruebas.
Véase la [configuración de generadores de Prisma](https://www.prisma.io/docs/orm/v6/prisma-schema/overview/generators).

`prisma:deploy` aplica la migración inicial sobre una base vacía y no vuelve a
aplicarla si ya está registrada. Para cambios posteriores en desarrollo:

```bash
npm run prisma:migrate --workspace=material-service -- --name nombre_del_cambio
```

Los archivos y la implementación de endpoints de materiales quedan para tareas
posteriores. Este cambio no migra ni modifica el modelo legado `Resource` de Catalog.

## Verificación

Desde `backend/`:

```bash
npm run lint:material
npm test --workspace=material-service -- --runInBand
npm run test:e2e --workspace=material-service -- --runInBand
curl http://localhost:3003/api/v1/health
```

Las pruebas HTTP verifican el prefijo, el healthcheck, Swagger UI y la ruta
documentada en OpenAPI. Sustituyen el proveedor Prisma y no requieren base de datos.

La prueba de integración requiere PostgreSQL y una cuenta con permiso para crear
esquemas. Desde `backend/`, después de generar el cliente:

```bash
MATERIAL_TEST_DATABASE_URL='postgresql://uct_admin:uct_password_123@localhost:5436/material_db' \
  npm run test:integration --workspace=material-service
```

Crea un esquema temporal de nombre aleatorio y lo elimina al terminar. Comprueba
la aplicación y reaplicación de la migración, la ausencia de diferencias frente
al esquema Prisma, el estado inicial, el historial de dos versiones, el rechazo
de versiones duplicadas o huérfanas y las claves foráneas exclusivamente locales.
No modifica el esquema `public` ni los datos de la aplicación.

El servicio participa en los comandos globales `build`, `lint`, `test`,
`test:ci` y `test:cov` del backend mediante npm workspaces.
