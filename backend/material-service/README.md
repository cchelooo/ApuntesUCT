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
| `GET http://localhost:3003/api/v1/materials` | Listado paginado de materiales publicados |
| `GET http://localhost:3003/api/v1/health` | Estado del proceso |
| `GET http://localhost:3003/api/docs` | Swagger UI |
| `GET http://localhost:3003/api/docs-json` | Especificación OpenAPI |

El healthcheck responde `200` con `status: "ok"`, `service: "material-service"`
y `timestamp` en formato ISO. No comprueba dependencias externas.
Las rutas de la API usan el prefijo `api/v1`; Swagger queda en `api/docs`.
CORS está habilitado siguiendo los demás servicios del backend.

## Listado paginado (#218)

`GET /api/v1/materials?page=1&pageSize=20` es público y consulta la base de
Material Service. Devuelve únicamente materiales `PUBLISHED`, ordenados por
`createdAt DESC, id DESC` (el ID resuelve empates de fecha).

| Parámetro | Predeterminado | Valores admitidos |
| --- | --- | --- |
| `page` | `1` | Entero decimal entre 1 y 2147483647 |
| `pageSize` | `20` | Entero decimal entre 1 y 100 |

El desplazamiento `(page - 1) * pageSize` no puede superar 2147483647.
Parámetros vacíos, repetidos, fraccionarios, fuera de rango o desconocidos
producen `400 Bad Request`. No acepta `q`, filtros académicos ni ordenamiento
personalizado: la búsqueda corresponde a Search Service.

Respuesta `200 OK`:

```json
{
  "items": [
    {
      "id": "c0bc574d-41a6-4cb6-9b0f-d3c48b216441",
      "title": "Apuntes de cálculo",
      "description": null,
      "uploaderId": "18b428c0-6879-4d34-9de8-df9a17438b28",
      "academicOfferingId": null,
      "universityId": null,
      "careerId": null,
      "subjectId": "calculo-1",
      "professorId": null,
      "materialTypeId": "73dfc2a6-7424-49a1-9449-c66b38cbe771",
      "materialType": "CLASS_NOTES",
      "academicYear": 2026,
      "status": "PUBLISHED",
      "verified": false,
      "createdAt": "2026-10-01T12:00:00.000Z",
      "updatedAt": "2026-10-01T12:00:00.000Z"
    }
  ],
  "page": 1,
  "pageSize": 20,
  "total": 1
}
```

Todos los campos del ejemplo están presentes; los campos opcionales del modelo
se serializan como `null`. `materialType` contiene el nombre del tipo local.
Las fechas se devuelven en ISO 8601 UTC. Las referencias a Auth y Catalog son
IDs lógicos; este endpoint no resuelve nombres ni consulta otros servicios.
No incluye versiones, claves de almacenamiento, URLs de descarga ni métricas
inventadas. El contrato también está documentado en Swagger/OpenAPI.

`total` cuenta todos los materiales publicados, no solo los de la página.
Sin publicaciones responde `{ "items": [], "page": 1, "pageSize": 20, "total": 0 }`.
Una página posterior a la última también responde `200` y conserva la página
solicitada y el total real, con `items: []`.
El cliente puede calcular `totalPages = ceil(total / pageSize)`.

El listado y el conteo comparten una transacción de lectura `RepeatableRead`.
Entre solicitudes independientes, nuevas publicaciones pueden desplazar las
páginas, como es habitual en paginación por desplazamiento.

Ejemplo directo al servicio:

```bash
curl 'http://localhost:3003/api/v1/materials?page=1&pageSize=20'
```

El proxy de `/api/v1/materials` en API Gateway corresponde a #222. Esta tarea
expone el endpoint en el puerto de Material Service (`3003`). Hay ejemplos
manuales en `backend/http/materials.http`.

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

La carga y descarga de archivos y los demás endpoints de materiales quedan para
tareas posteriores. El listado no modifica el modelo legado `Resource` de Catalog.

## Verificación

Desde `backend/`:

```bash
npm run lint:material
npm test --workspace=material-service -- --runInBand
npm run test:e2e --workspace=material-service -- --runInBand
curl http://localhost:3003/api/v1/health
```

Las pruebas HTTP verifican el prefijo, el healthcheck, Swagger UI y la ruta
documentada en OpenAPI, además del contrato paginado, el cálculo del desplazamiento,
el filtro de publicados, el orden estable, la serialización y los errores de consulta.
Sustituyen el proveedor Prisma y no requieren base de datos; no verifican la
ejecución de las consultas contra PostgreSQL.

Las pruebas de integración requieren PostgreSQL y una cuenta con permiso para crear
esquemas. Desde `backend/`, después de generar el cliente:

```bash
npm run build --workspace=material-service
MATERIAL_TEST_DATABASE_URL='postgresql://uct_admin:uct_password_123@localhost:5436/material_db' \
  npm run test:integration --workspace=material-service
```

Cada prueba crea un esquema temporal de nombre aleatorio y lo elimina al terminar.
La prueba de persistencia comprueba
la aplicación y reaplicación de la migración, la ausencia de diferencias frente
al esquema Prisma, el estado inicial, el historial de dos versiones, el rechazo
de versiones duplicadas o huérfanas y las claves foráneas exclusivamente locales.
La prueba `test/materials.integration.cjs` levanta la aplicación compilada con
Prisma real en un puerto HTTP local temporal. Comprueba una base vacía, la
exclusión de `PENDING_REVIEW`, `REJECTED` y `WITHDRAWN`, páginas consecutivas sin
duplicados con empates de fecha, el total de publicados, la serialización de
metadatos, páginas fuera de rango y errores `400`. También verifica que una base
con solo materiales no publicados devuelva una página vacía y que el esquema
temporal se elimine al finalizar.
No modifican el esquema `public` ni los datos de la aplicación.

El servicio participa en los comandos globales `build`, `lint`, `test`,
`test:ci` y `test:cov` del backend mediante npm workspaces.


## Relación del contrato de creación con los tipos persistidos

`POST /api/v1/materials` sigue siendo un contrato simulado: no persiste materiales,
no busca tipos en la base y no devuelve un `materialTypeId` inventado.
Su respuesta inicial documenta únicamente `PENDING_REVIEW`.

Al implementar la persistencia, el servidor resolverá el código público `type`
por coincidencia exacta con el nombre único de un registro activo de `MaterialType`:

| `type` del POST | `MaterialType.name` a resolver |
| --- | --- |
| `DOCUMENT` | `DOCUMENT` |
| `PRESENTATION` | `PRESENTATION` |
| `LINK` | `LINK` |
| `EXAM` | `EXAM` |
| `SUMMARY` | `SUMMARY` |

El ID de ese registro será `Material.materialTypeId`. El listado existente
`GET /api/v1/materials` expone ese ID como `materialTypeId` y su nombre como
`materialType`. No se confunden códigos con UUIDs. Los registros deberán existir
al habilitar la creación real; un tipo inexistente o inactivo deberá rechazarse
como metadato inválido. Esta corrección no agrega seeds ni consultas de persistencia.
El enum de creación es un subconjunto admitido por el POST; el listado puede
contener otros tipos ya persistidos, como `CLASS_NOTES`, sin modificar su contrato.

Los MIME locales documentados son:

- PDF: `application/pdf`.
- Word .doc: `application/msword`.
- Word .docx: `application/vnd.openxmlformats-officedocument.wordprocessingml.document`.
- PowerPoint .ppt: `application/vnd.ms-powerpoint`.
- PowerPoint .pptx: `application/vnd.openxmlformats-officedocument.presentationml.presentation`.
