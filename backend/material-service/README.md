# Material Service

Microservicio NestJS de materiales académicos con persistencia Prisma (#217).
Requiere Node.js 22, npm y PostgreSQL. Usa `db-material` de Docker Compose
(contenedor `db_material`, base `material_db`, puerto local `5436`).
MinIO se utiliza al guardar y descargar archivos mediante el adaptador interno (#231, #236).
El listado y healthcheck no requieren conectarse a MinIO; la subida con archivo y la
descarga sí.

## Instalación y ejecución

Desde la raíz del repositorio:

```bash
cp .env.example .env # solo si no existe; completar credenciales de MinIO
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
| `POST http://localhost:3003/api/v1/materials` | Creación y subida real (contexto de autor local temporal) |
| `GET http://localhost:3003/api/v1/materials` | Listado paginado de materiales publicados |
| `GET http://localhost:3003/api/v1/materials/:id/download` | Descarga del archivo de un material publicado |
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

## Descarga de materiales (#236)

`GET /api/v1/materials/:id/download` descarga el archivo de la **última versión** del
material (`versionNumber` mayor) o la versión indicada con `?versionId=<uuid>`.
Solo sirve materiales `PUBLISHED`; el ID del material debe ser un UUID.

| Parámetro | Tipo | Descripción |
| --- | --- | --- |
| `id` | UUID (path) | Identificador del material. |
| `versionId` | UUID (query, opcional) | Versión concreta a descargar; por defecto la última. |

La versión se resuelve internamente en base de datos; el servidor solo guarda la
`storageKey` y no la expone en ningún momento. El archivo se streama desde MinIO
leyendo la clave almacenada en `MaterialVersion.storageKey`; no se genera una URL
firmada ni se devuelve la ruta interna del bucket.

Respuesta `200 OK` (stream):

- `Content-Type`: el MIME persistido de la versión (`MaterialVersion.mimeType`).
- `Content-Disposition: attachment; filename="<ASCII>"; filename*=UTF-8''<nombre original>`.
  El nombre original se conserva codificado en UTF-8 (RFC 5987) en `filename*` para
  clientes modernos; `filename` es una alternativa ASCII segura (sin tildes, ñ ni otros
  caracteres no imprimibles) que neutraliza comillas y CR/LF para evitar inyección de
  cabeceras. Si el nombre queda vacío se usa `material`.
- `Content-Length`: el tamaño persistido (`MaterialVersion.fileSize`).

Errores:

| Código | Caso |
| --- | --- |
| `400` | UUID inválido, `versionId` no UUID o parámetro desconocido en la query. |
| `404` | Material inexistente o no publicado, versión inexistente del material, o clave ausente en MinIO. |
| `503` | Almacenamiento no disponible o error de lectura interno. |

El filtro HTTP global no interviene en el streaming: el cuerpo viaja byte a byte.
La resolución del material y de la versión se consultan en PostgreSQL antes de tocar
MinIO, por lo que un material sin versiones responde `404` sin depender del almacenamiento.

Este endpoint no forma parte del listado: no agrega versiones, claves ni URLs al
contrato paginado. La descarga también está disponible en el Gateway `#222`
(`/api/v1/materials/:id/download`), que retransmite el stream y sus cabeceras.

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
los materiales y su historial. La creación (#233) guarda metadatos y la primera versión. La actualización de
versiones y las transiciones de estado corresponden a futuros casos de uso.

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

Los endpoints restantes de materiales y las transiciones de estado quedan para
tareas posteriores. El listado no modifica el modelo legado `Resource` de Catalog.
La descarga de materiales publicados se implementa en `#236` (sección anterior).

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

`POST /api/v1/materials` persiste materiales y resuelve el tipo en la base.
Su respuesta inicial documenta únicamente `PENDING_REVIEW`.

El servidor resuelve el código público `type`
por coincidencia exacta con el nombre único de un registro activo de `MaterialType`:

| `type` del POST | `MaterialType.name` a resolver |
| --- | --- |
| `DOCUMENT` | `DOCUMENT` |
| `PRESENTATION` | `PRESENTATION` |
| `LINK` | `LINK` |
| `EXAM` | `EXAM` |
| `SUMMARY` | `SUMMARY` |

El ID de ese registro es `Material.materialTypeId`. El listado existente
`GET /api/v1/materials` expone ese ID como `materialTypeId` y su nombre como
`materialType`. No se confunden códigos con UUIDs. La migración de #233 incorpora los cinco tipos sin modificar los existentes.
Un tipo inexistente o inactivo se rechaza con 400 antes de guardar archivos.
El enum de creación es un subconjunto admitido por el POST; el listado puede
contener otros tipos ya persistidos, como `CLASS_NOTES`, sin modificar su contrato.

Los MIME locales documentados son:

- PDF: `application/pdf`.
- Word .doc: `application/msword`.
- Word .docx: `application/vnd.openxmlformats-officedocument.wordprocessingml.document`.
- PowerPoint .ppt: `application/vnd.ms-powerpoint`.
- PowerPoint .pptx: `application/vnd.openxmlformats-officedocument.presentationml.presentation`.

### Validación del archivo

Se permiten hasta **15 728 640 bytes inclusive**. Multer limita la recepción y
el validador vuelve a comprobar el tamaño. El MIME de la respuesta se obtiene
del contenido: el nombre del archivo y su MIME declarado no determinan la aceptación.
PDF, DOCX y PPTX usan la detección de Nest; DOC y PPT se identifican leyendo su
contenedor CFB y los streams de Word/PowerPoint. Un archivo XLS, un contenedor
dañado o texto renombrado a PDF se rechazan con `415`.
Esto valida el formato, no sustituye análisis antimalware.


## Adaptador de almacenamiento MinIO (#231)

`StorageModule` exporta el puerto `ObjectStorage` y está importado en
`MaterialsModule`. Los casos de uso pueden inyectar `ObjectStorage` y llamar a
`save(buffer, mimeType)` y a `get(storageKey)`. La implementación usa el SDK oficial
[MinIO JavaScript](https://github.com/minio/minio-js/blob/master/docs/API.md).

Cada escritura genera `materials/<UUID>` y devuelve `{ storageKey }` **solo para
uso interno** (por ejemplo, `MaterialVersion.storageKey`). No acepta el nombre
original del usuario ni devuelve endpoints, buckets, credenciales o URLs firmadas.
`get` lee el objeto por su clave y devuelve un stream de bytes; una clave ausente
se convierte en `ObjectNotFoundError` y los demás fallos en `ObjectStorageError`.
El MIME debe haber sido validado por el caso de uso antes de guardar. Los errores
de configuración o escritura también se convierten en `ObjectStorageError` sin
incluir los detalles del SDK. El filtro HTTP existente lo presenta como un error
genérico 500 si llega sin traducir a una ruta HTTP; el caso de uso de creación lo
traduce a 502 y la descarga a 404/503 sin detalles internos.

La configuración y el cliente se inicializan en la primera escritura. No se
realizan conexiones durante el arranque. Las variables se validan antes de
crear el cliente; no se aceptan credenciales vacías.

| Variable | Uso |
| --- | --- |
| `MINIO_ENDPOINT` | Host sin protocolo ni ruta; `localhost` en desarrollo, `minio` desde la red Compose |
| `MINIO_PORT` | Puerto S3, por defecto `9000` (no el de la consola) |
| `MINIO_USE_SSL` | Literal `true` o `false`, por defecto `false` para desarrollo local |
| `MINIO_BUCKET` | Nombre del bucket privado existente |
| `MINIO_ACCESS_KEY` | Credencial del usuario de servicio |
| `MINIO_SECRET_KEY` | Secreto del usuario de servicio |

### Preparación local

1. Copiar `.env.example` de la raíz a `.env` si no existe y completar
   `MINIO_ROOT_USER` y `MINIO_ROOT_PASSWORD` con valores propios (contraseña de
   al menos 8 caracteres). Compose exige estas variables incluso al iniciar
   otros servicios. Son credenciales administrativas, distintas de las del servicio.
2. Ejecutar `docker compose up -d minio` desde la raíz. Los puertos S3 y consola
   se publican únicamente en loopback para desarrollo local.
3. Entrar a `http://localhost:9001` con esas credenciales y crear el bucket
   `materials`. Mantener su acceso **privado**, sin política anónima.
4. Crear credenciales de servicio con permisos `s3:PutObject` y `s3:DeleteObject` sobre
   `arn:aws:s3:::materials/*` y `s3:GetBucketLocation` sobre
   `arn:aws:s3:::materials`. Copiarlas en `material-service/.env`, junto con
   las variables indicadas en su `.env.example`.

El adaptador requiere un bucket provisionado: no crea buckets ni cambia políticas
de acceso. El POST usa este adaptador desde el caso de uso de creación (#233) y la
descarga también lo consume desde `#236`.

### Prueba contra MinIO real

Desde `backend/material-service`, con variables MinIO exportadas en el proceso:

```bash
MATERIAL_TEST_MINIO=1 npm run test:storage
```

Esta prueba necesita credenciales de prueba que permitan crear/eliminar buckets
y leer/escribir/eliminar objetos. Crea un bucket privado temporal con nombre UUID,
verifica contenido, tamaño, MIME, claves distintas y rechazo del acceso anónimo,
además de un round-trip de lectura con `get` y el `404` interno cuando la clave no
existe; luego elimina sus propios objetos y bucket. No usa ni modifica el bucket de la
aplicación. Sin `MATERIAL_TEST_MINIO=1` se omite. No carga automáticamente `.env`.


## Creación y subida (#233)

Esta rama parte de `feature/231-adaptador-almacenamiento-minio`, pendiente de
revisión. El diff de #233 debe revisarse contra esa rama hasta integrar #231.

Aplicar la nueva migración antes de ejecutar el servicio:

```bash
cd backend
npm run prisma:generate --workspace=material-service
npm run prisma:deploy --workspace=material-service
```

La migración agrega `Material.externalLink` nullable y los cinco tipos del POST.
No reinicia tablas ni cambia tipos ya existentes, incluidos los desactivados.

### Autor temporal de desarrollo

Auth todavía entrega tokens simulados sin firma. Esos tokens **no autorizan**
este endpoint. Hasta integrar Auth real, el POST requiere configurar explícitamente
en `material-service/.env`:

```dotenv
NODE_ENV=development
MATERIAL_LOCAL_AUTHOR_ENABLED=true
MATERIAL_LOCAL_UPLOADER_ID=<UUID-del-autor-de-prueba>
MATERIAL_LOCAL_UNIVERSITY_ID=<ID-institucional-opcional>
```

Este modo asigna el mismo autor configurado a todas las subidas locales. No es
un mecanismo de autenticación. Fuera de `NODE_ENV=development`, con el modo
apagado o sin UUID válido, el POST responde 401. Está apagado por defecto y no
acepta IDs de autor enviados en el body. El despliegue con autenticación real
requiere reemplazar `MaterialAuthorProvider` por contexto verificado de Auth.
Las referencias académicas se guardan como IDs lógicos; la comprobación de su
existencia en Catalog sigue pendiente. Universidad es null si no está configurada.

### Flujo y consistencia

1. Validar multipart, formato/tamaño del archivo y reglas archivo/enlace.
2. Resolver un tipo activo por nombre. LINK requiere URL HTTP(S), sin archivo.
3. Para archivos, confirmar primero la escritura en MinIO.
4. Crear material y primera versión mediante escritura anidada transaccional
   de Prisma, con estado `PENDING_REVIEW`, tamaño real y checksum SHA-256.
5. Devolver 201 con ID y fecha reales, `isSimulatedResponse: false` y metadatos
   públicos. `fileUrl` permanece null: la descarga se realiza por
   `GET /materials/:id/download` (#236) sin exponer claves, rutas ni credenciales de MinIO.

LINK guarda `externalLink` en Material sin versión binaria. Los demás tipos
requieren archivo y permiten guardar también una URL de respaldo.
Un fallo de MinIO devuelve 502 sin insertar material ni versión. Un fallo al
insertar la versión revierte también el material y devuelve 500.
Si PostgreSQL confirma un rechazo/rollback, el caso de uso consulta si existe una
versión que use la clave recién subida. Si no existe, elimina ese objeto de MinIO.
La limpieza no reemplaza el error original ni elimina objetos referenciados.
PostgreSQL y MinIO no comparten transacción: ante errores de conexión/commit
incierto, se conserva el archivo para no borrar una subida posiblemente válida.
Si no puede verificarse la referencia o falla el borrado, se registra una advertencia
interna con la clave para su revisión. No hay reintentos persistentes ni barrido
periódico: esas situaciones y una caída del proceso aún pueden dejar objetos
huérfanos. No se promete atomicidad entre sistemas ni idempotencia HTTP.

Ejemplo con archivo, tras configurar el contexto local y el bucket privado:

```bash
curl -X POST http://localhost:3003/api/v1/materials \
  -F 'title=Apuntes de álgebra' -F 'year=2026' -F 'type=DOCUMENT' \
  -F 'subjectId=SUBJ-102' -F 'file=@/ruta/apuntes.pdf'
```

Ejemplo con enlace:

```bash
curl -X POST http://localhost:3003/api/v1/materials \
  -F 'title=Clase grabada' -F 'year=2026' -F 'type=LINK' \
  -F 'subjectId=SUBJ-102' -F 'externalLink=https://example.com/clase'
```

### Verificación de creación real

Desde `backend/material-service`, después del build, exportar las credenciales
MinIO de pruebas y `MATERIAL_TEST_DATABASE_URL`, y ejecutar:

```bash
MATERIAL_TEST_UPLOAD=1 node --test test/create-material.integration.cjs
```

La prueba usa un esquema PostgreSQL y un bucket MinIO temporales. Comprueba los
cuatro tipos de archivo, LINK, los bytes almacenados, checksum, metadatos, autor,
validaciones, rechazo de tipos inactivos, fallo real de MinIO y rollback de la
creación anidada. Elimina sus propios recursos al terminar. No modifica los datos
del servicio ni requiere migrar el esquema de la aplicación para probarse.

### Crear una nueva versión de archivo (#246)

`POST /api/v1/materials/:id/versions` recibe `multipart/form-data` con un campo
`file` obligatorio (PDF, Word o PowerPoint, hasta 15 MiB, con validación de contenido).
Solo el autor del material puede agregar versiones. Usa el contexto temporal de
`MaterialAuthorProvider`, disponible actualmente en desarrollo; los materiales
`LINK` no admiten versiones de archivo.

```bash
curl -X POST "http://localhost:3003/api/v1/materials/$MATERIAL_ID/versions" \
  -F "file=@apunte-actualizado.pdf"
```

Devuelve `201` con `id`, `materialId`, `versionNumber`, `originalFilename`,
`mimeType`, `fileSize` (string), `createdBy` y `createdAt`. La clave interna del
objeto no se expone. Cada carga crea un objeto independiente y una fila nueva;
el nombre original puede repetirse sin sobrescribir archivos. Una transacción
bloquea la fila del material antes de calcular el siguiente número, serializando
cargas concurrentes. Se actualiza `updatedAt`; el estado y los metadatos del
material se conservan. La descarga existente permite recuperar versiones previas
con `GET /api/v1/materials/:id/download?versionId=:versionId`.

Los errores incluyen `400` (UUID/archivo inválido o LINK), `401` (sin contexto de
autor), `403` (otro autor), `404` (material inexistente), `413` (tamaño), `415`
(formato) y `502` (almacenamiento). Ante rollback confirmado se intenta eliminar
solo el objeto nuevo sin referencias; si el resultado de persistencia es incierto,
se conserva y se registra la limpieza pendiente, como en la creación inicial.

Prueba de concurrencia con PostgreSQL real y almacenamiento en memoria (crea y
elimina un esquema temporal; no modifica los materiales existentes):

```bash
npm run build
MATERIAL_TEST_DATABASE_URL='postgresql://usuario:clave@localhost:5436/material_db' \
  node --test test/create-material-version.integration.cjs
```

Prueba HTTP con PostgreSQL **y MinIO reales**, usando el adaptador de producción:

```bash
npm run build
# Configurar MATERIAL_TEST_DATABASE_URL y MINIO_ENDPOINT, MINIO_PORT,
# MINIO_USE_SSL, MINIO_ACCESS_KEY, MINIO_SECRET_KEY en el entorno de prueba.
MATERIAL_TEST_MINIO=1 node --test test/material-version-minio.integration.cjs
```

Requiere credenciales de prueba con permisos para crear y eliminar un bucket
temporal. La prueba crea una versión inicial y envía dos cargas HTTP simultáneas
con el mismo nombre de archivo; verifica números 1/2/3, claves distintas, checksum,
contenido y tamaño en MinIO, descarga HTTP histórica y descarga de la última
versión. Al finalizar elimina el bucket y el esquema propios, incluso ante fallos.
