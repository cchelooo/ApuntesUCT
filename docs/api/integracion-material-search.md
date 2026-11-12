# Integración de Material y Search — Sprint 2 (#262)

Referencia actual para INT2 e INT4. Los ejemplos son ilustrativos; usar UUID de
Catalog y materiales reales del entorno. El contrato completo de campos está en
[OpenAPI generado](apuntesuct.openapi.json), y las peticiones en
[Postman](apuntesuct.postman_collection.json).

## Entrada pública y arranque

Todas las rutas de esta guía se concatenan con `http://localhost:3000` (Gateway).
Mobile configura `API_GATEWAY_URL=http://10.0.2.2:3000/api/v1` en Android Emulator;
en dispositivo físico usa la IP LAN del host. No accede a los puertos internos.

| Servicio | Puerto | Comando desde `backend/`, una terminal por servicio |
| --- | --- | --- |
| Gateway | 3000 | `PORT=3000 npm run start:dev --workspace=api-gateway` |
| Auth | 3001 | `PORT=3001 npm run start:dev --workspace=auth-service` |
| Catalog | 3002 | `PORT=3002 npm run start:dev --workspace=catalog-service` |
| Material | 3003 | `PORT=3003 npm run start:dev --workspace=material-service` |
| Search | 3005 | `PORT=3005 npm run start:dev --workspace=search-service` |

Preparar `.env`, bases y migraciones según [Backend](../../backend/README.md),
[Catalog](../../backend/catalog-service/README.md) y
[Material](../../backend/material-service/README.md). Desde la raíz se pueden
levantar `docker compose up -d db-auth db-catalog db-material minio`.
Desde `backend/`: `npm install`, `npm run prisma:generate` y
`npm run prisma:deploy --workspace=material-service`. Aplicar también las
migraciones y seed de Catalog según su README. Configurar el bucket y credenciales
MinIO; levantar el contenedor por sí solo no configura el bucket.

Search no usa base propia: `CATALOG_SERVICE_URL=http://localhost:3002` y
`MATERIAL_SERVICE_URL=http://localhost:3003` son sus destinos internos (sin `/api/v1`).
Material usa `CATALOG_SERVICE_URL=http://localhost:3002/api/v1` (con prefijo).
El Gateway usa las URLs internas sin prefijo. Mantener estas variables por proceso.

## Autenticación y visibilidad

Auth verifica credenciales registradas y emite JWT RS256; configurar su clave,
emisor y audiencia según el [README de Auth](../../backend/auth-service/README.md).
La integración de esa identidad en Material está pendiente. Las lecturas son
públicas. Los POST de Material resuelven un contexto local de autor, que solo
funciona con estas variables en el proceso de Material:

```dotenv
NODE_ENV=development
MATERIAL_LOCAL_AUTHOR_ENABLED=true
MATERIAL_LOCAL_UPLOADER_ID=00000000-0000-4000-8000-000000000092
```

`MATERIAL_LOCAL_UNIVERSITY_ID` es opcional y restringe la universidad compatible.
Sin contexto habilitado/válido se responde `401` cuando la solicitud supera las
validaciones previas. El contexto es común al proceso, no se deriva del Bearer ni
representa autenticación real. Crear versiones exige el mismo autor (`403` si difiere).

Una subida crea un material **PENDING_REVIEW**. Listado, detalle y descarga leen
**PUBLISHED**. No usar automáticamente el ID recién subido para esperar un detalle
`200`: puede devolver `404` hasta que el material esté publicado. Para las pruebas
de lectura usar datos publicados del entorno; esta colección no agrega una ruta
de publicación que el backend no ofrece.

## Operaciones

| Método y ruta | Entrada | Respuesta |
| --- | --- | --- |
| `GET /api/v1/materials` | `page=1`, `pageSize=20` | `200 { items, page, pageSize, total }` |
| `POST /api/v1/materials` | multipart con metadatos y archivo o enlace | `201 { status, isSimulatedResponse, message, data }` |
| `GET /api/v1/materials/{id}` | UUID publicado | `200` detalle con `currentVersion` y `versions` |
| `GET /api/v1/materials/{id}/download` | `versionId` UUID opcional | `200` archivo binario |
| `POST /api/v1/materials/{id}/versions` | multipart, campo `file` obligatorio | `201` versión nueva |
| `GET /api/v1/search` | texto, filtros, orden y paginación | `200 { query, page, pageSize, total, results, context }` |

### Listado y detalle

Material solo acepta `page` y `pageSize`. Página desde 1, tamaño 1–100, valor
predeterminado 20, desplazamiento máximo 2147483647. Orden `createdAt DESC, id DESC`.
No enviar `q` ni filtros de búsqueda al listado: parámetros desconocidos dan `400`.

```bash
curl 'http://localhost:3000/api/v1/materials?page=1&pageSize=20'
curl "http://localhost:3000/api/v1/materials/$MATERIAL_ID"
```

Ejemplo de listado sin datos:

```json
{ "items": [], "page": 1, "pageSize": 20, "total": 0 }
```

Cada item contiene `id`, `title`, `description`, `uploaderId`, `academicOfferingId`,
`universityId`, `careerId`, `subjectId`, `professorId`, `materialTypeId`, `materialType`,
`academicYear`, `status`, `verified`, `createdAt` y `updatedAt`. Los campos académicos
opcionales y la descripción pueden ser null; fechas ISO. El detalle añade
`externalLink`, `currentVersion` y `versions` (ver ejemplo completo en Postman).

`versions` incluye la actual y se ordena por `versionNumber DESC`. Cada versión
contiene `id`, `versionNumber`, `originalFilename`, `mimeType`, `fileSize` y
`createdAt`. **fileSize es una cadena decimal de bytes**, no número. Un `LINK`
sin archivo tiene `currentVersion: null` y `versions: []`. Un documento publicado
sin versión responde `404`. No se exponen claves de almacenamiento.

### Subida multipart

| Campo | Regla |
| --- | --- |
| `title` | Obligatorio, texto no vacío |
| `year` | Obligatorio, texto de cuatro dígitos, 1900–2099 |
| `type` | `DOCUMENT`, `PRESENTATION`, `LINK`, `EXAM`, `SUMMARY`; debe existir activo en Material |
| `subjectId` | Obligatorio, UUID de asignatura activa con carrera/universidad activas |
| `description` | Opcional |
| `careerId`, `professorId` | Opcionales, UUID existentes, activos y compatibles con asignatura |
| `file` | Obligatorio salvo LINK; archivo local no vacío, máximo 15.728.640 bytes |
| `externalLink` | URL http/https; obligatoria para LINK, que prohíbe file |

Archivos admitidos: PDF (`application/pdf`), DOC (`application/msword`), DOCX
(`application/vnd.openxmlformats-officedocument.wordprocessingml.document`), PPT
(`application/vnd.ms-powerpoint`) y PPTX
(`application/vnd.openxmlformats-officedocument.presentationml.presentation`).
Se valida contenido, no basta con cambiar extensión o MIME.

```bash
curl -X POST http://localhost:3000/api/v1/materials \
  -F 'title=Guía de álgebra' -F 'year=2026' -F 'type=DOCUMENT' \
  -F "subjectId=$SUBJECT_ID" -F 'file=@./guia.pdf;type=application/pdf'
```

`201` devuelve `status: "success"`, `isSimulatedResponse: false`, `message` y `data`.
`data` incluye `id`, `title`, `description`, `year` (string), `type`,
`status: "PENDING_REVIEW"`, referencias académicas, `fileUrl: null`, `fileSize`
(número o null en esta respuesta de creación), `mimeType`, `externalLink` y
`createdAt`. No confundir `year/type` de creación con `academicYear/materialType`
de lectura. Postman incluye una respuesta completa ilustrativa.

### Versionado y descarga

```bash
curl -X POST "http://localhost:3000/api/v1/materials/$MATERIAL_ID/versions" \
  -F 'file=@./guia-v2.pdf;type=application/pdf'
curl "http://localhost:3000/api/v1/materials/$MATERIAL_ID/download" -o guia.pdf
curl "http://localhost:3000/api/v1/materials/$MATERIAL_ID/download?versionId=$VERSION_ID" -o guia-anterior.pdf
```

Crear versión conserva las anteriores, incrementa `versionNumber` y no cambia el
estado del material. LINK no admite versiones. Respuesta `201`:

```json
{
  "id": "00000000-0000-4000-8000-000000000002",
  "materialId": "00000000-0000-4000-8000-000000000001",
  "versionNumber": 2,
  "originalFilename": "guia-v2.pdf",
  "mimeType": "application/pdf",
  "fileSize": "2048",
  "createdBy": "00000000-0000-4000-8000-000000000092",
  "createdAt": "2026-11-08T12:00:00.000Z"
}
```

Descarga devuelve bytes, con `Content-Type` del archivo, `Content-Length` y
`Content-Disposition: attachment` (nombre original codificado). No devuelve JSON,
URL de MinIO ni redirección. Sin `versionId`, elige la mayor `versionNumber`.
Versión ajena, archivo inexistente o material no publicado producen `404`.

### Search

```bash
curl 'http://localhost:3000/api/v1/search?q=algebra&year=2026&type=DOCUMENT&page=1&pageSize=20&sortBy=year&order=desc'
```

- `q`: hasta 200 caracteres, coincidencia parcial en título/descripción sin
  distinguir mayúsculas o tildes. Vacío equivale a omitirlo.
- `universityId → careerId → subjectId → professorId`: UUID opcionales en orden;
  cada nivel requiere todos sus anteriores. Combinaciones incompatibles no generan coincidencias.
- `year`: entero 1900–2099; `type`: nombre exacto de `materialType`, sensible a
  mayúsculas, hasta 100 caracteres, no vacío. Ambos independientes de jerarquía.
  Search no limita `type` al enum del POST; un nombre sin coincidencias devuelve total 0.
- `sortBy`: `createdAt` (predeterminado), `title` o `year`.
- `order`: `asc` o `desc` (predeterminado); empates por `id DESC`, nulos al final.
- `page`: desde 1; `pageSize`: 1–100, predeterminado 20. Se pagina el resultado
  final después de filtrar/ordenar, no cada dependencia por separado.

Ejemplo sin coincidencias ni contexto académico:

```json
{ "query": "algebra", "page": 1, "pageSize": 20, "total": 0, "results": [], "context": [] }
```

Sin `q`, `query` es null. `results` contiene identificadores, título, descripción,
`materialType`, `academicYear`, `verified`, IDs/nombres académicos y fechas.
`context` contiene asignaturas, carrera/universidad y profesores del contexto
académico (es independiente del conteo de resultados). Consultar sus campos y
nulabilidad en OpenAPI. Las páginas no constituyen una instantánea; cambios
concurrentes detectables pueden producir `502` y requieren reintento.

## Errores

| Estado | Situaciones |
| --- | --- |
| `400` | DTO/query/UUID inválidos, jerarquía incompleta, archivo vacío, referencias incompatibles, LINK con archivo |
| `401` | POST sin contexto válido de autor local |
| `403` | Crear versión con un autor diferente |
| `404` | Material no encontrado/no publicado en lectura, versión o archivo inexistente |
| `413` | Archivo supera 15 MiB |
| `415` | Tipo/contenido de archivo no admitido |
| `502` | Gateway no alcanza destino; Material no alcanza Catalog/almacenamiento; Search recibe payload inválido |
| `503` | Search no puede consultar Catalog o Material; Material no puede acceder al almacenamiento durante descarga |

Material añade `timestamp` y `path`; `message` puede ser string o array, y errores
académicos pueden incluir `field`. Ejemplo `401`:

```json
{
  "statusCode": 401,
  "error": "Unauthorized",
  "message": "Se requiere un contexto de autor válido.",
  "timestamp": "2026-11-08T12:00:00.000Z",
  "path": "/api/v1/materials"
}
```

Gateway usa un formato distinto para destino caído:

```json
{ "statusCode": 502, "message": "Material Service no disponible" }
```

Search usa `{ statusCode, message, error }`. No exigir `error`, `timestamp` ni
`path` universalmente. Conservar el estado HTTP para distinguir validación,
autorización, ausencia y dependencia indisponible. La colección incluye ejemplos
Material de `401`, `404`, `413`, `415` y `502`.
