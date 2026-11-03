# Regresión manual contra el stack real (#268)

Esta guía permite repetir desde la Web los siete flujos integrados con servicios
locales reales: catálogo, login mock, listado, subida, detalle, descarga y
búsqueda. Las peticiones de la Web pasan por API Gateway. No es una suite E2E
automatizada ni se ejecuta en CI.

## Alcance y condiciones

- Docker Compose levanta PostgreSQL y MinIO; los microservicios y la Web se
  ejecutan por separado con Node.js. Search Service no usa base de datos, pero
  depende de Catalog y Material.
- En una instalación limpia, las bases no contienen publicaciones. El seed de
  Catalog proporciona registros académicos para seleccionar en el formulario,
  pero no crea materiales publicados ni archivos válidos en MinIO.
- La subida funcional crea material en `PENDING_REVIEW`. Listado y búsqueda
  solo consideran materiales publicados; detalle y descarga requieren un
  material publicado, y para descargar además debe existir una versión y su
  objeto en MinIO.
- El login es deliberadamente simulado: valida el formato de los datos, no
  autentica una cuenta, y no establece una sesión en la Web.

## Preparación local (Windows PowerShell)

Requisitos: Node.js 22, npm y Docker Compose. Ejecutar los comandos desde la
raíz del repositorio, salvo que se indique otra carpeta.

1. Preparar las credenciales locales y la infraestructura:

   ```powershell
   if (-not (Test-Path .env)) { Copy-Item .env.example .env }
   ```

   Completar `MINIO_ROOT_USER` y `MINIO_ROOT_PASSWORD` en `.env` con valores
   locales propios (contraseña de al menos 8 caracteres). No versionar ese
   archivo. Luego iniciar la infraestructura:

   ```powershell
   docker compose up -d
   docker compose ps
   ```

   MinIO publica la API S3 en `http://localhost:9000` y la consola en
   `http://localhost:9001`, solo en loopback. El volumen `minio_data` conserva
   los objetos entre reinicios; `docker compose down -v` también lo elimina.

2. Crear los archivos locales de configuración de los servicios si aún no
   existen:

   ```powershell
   if (-not (Test-Path backend\auth-service\.env)) { Copy-Item backend\auth-service\.env.example backend\auth-service\.env }
   if (-not (Test-Path backend\catalog-service\.env)) { Copy-Item backend\catalog-service\.env.example backend\catalog-service\.env }
   if (-not (Test-Path backend\material-service\.env)) { Copy-Item backend\material-service\.env.example backend\material-service\.env }
   if (-not (Test-Path web\.env)) { Copy-Item web\.env.example web\.env }
   ```

   Revisar las URL `DATABASE_URL` de Auth, Catalog y Material contra los
   puertos de Compose (`5432`, `5433` y `5436`, respectivamente). En
   `backend\material-service\.env`, configurar `MINIO_ENDPOINT=localhost`,
   `MINIO_PORT=9000`, `MINIO_USE_SSL=false` y `MINIO_BUCKET=materials`.
   Crear el bucket privado `materials` en la consola de MinIO. El adaptador no
   crea buckets. Crear también las credenciales de servicio con los permisos
   descritos en [la guía de almacenamiento de Material Service](../../backend/material-service/README.md)
   y asignarlas a `MINIO_ACCESS_KEY` y `MINIO_SECRET_KEY`; no es necesario
   usar las credenciales administrativas de MinIO para la aplicación.

   Para habilitar la subida local, configurar en ese mismo archivo
   `NODE_ENV=development`, `MATERIAL_LOCAL_AUTHOR_ENABLED=true` y
   `MATERIAL_LOCAL_UPLOADER_ID` con un UUID. Este contexto es temporal y no
   representa autenticación. `MATERIAL_LOCAL_UNIVERSITY_ID` puede quedar vacío;
   si se configura, debe corresponder a la universidad activa de la asignatura.
   El servicio sigue validando referencias académicas reales y archivos de
   hasta 15.728.640 bytes.

   En `web\.env`, establecer `VITE_API_URL=http://localhost:3000/api/v1`.

3. Generar clientes, aplicar migraciones y cargar los datos académicos de
   ejemplo. Desde `backend`:

   ```powershell
   Set-Location backend
   npm ci
   npm run prisma:generate
   npm run prisma:deploy --workspace=auth-service
   npm run prisma:deploy --workspace=catalog-service
   npm run prisma:seed --workspace=catalog-service
   npm run prisma:deploy --workspace=material-service
   ```

   El seed de Catalog imprime los UUID de la universidad, carrera, profesor y
   asignatura. El servicio de subida requiere elegir referencias activas y
   compatibles de ese catálogo.

4. Iniciar cada servicio en una terminal independiente. Abrirlas desde la raíz
   del repositorio:

   ```powershell
   Set-Location backend\api-gateway
   npm run start:dev
   ```

   ```powershell
   Set-Location backend\auth-service
   npm run start:dev
   ```

   ```powershell
   Set-Location backend\catalog-service
   $env:PORT = "3002"
   npm run start:dev
   ```

   ```powershell
   Set-Location backend\material-service
   $env:NODE_ENV = "development"
   npm run start:dev
   ```

   ```powershell
   Set-Location backend\search-service
   npm run start:dev
   ```

   Iniciar la Web en otra terminal:

   ```powershell
   Set-Location web
   npm ci
   npm run dev
   ```

   Abrir la URL local que informa Vite (por defecto `http://localhost:5173`).
   Los puertos HTTP esperados son Gateway `3000`, Auth `3001`, Catalog `3002`,
   Material `3003` y Search `3005`.

## Comprobación previa

Gateway, Auth, Material y Search exponen health bajo `/api/v1/health`;
Catalog lo expone en `/health`. Desde PowerShell se puede comprobar con
`curl.exe`:

```powershell
curl.exe -i http://localhost:3000/api/v1/health
curl.exe -i http://localhost:3001/api/v1/health
curl.exe -i http://localhost:3002/health
curl.exe -i http://localhost:3003/api/v1/health
curl.exe -i http://localhost:3005/api/v1/health
```

Cada endpoint debe responder `200`. Un servicio apagado genera `502` al
consultarlo a través del Gateway; un health `200` no garantiza que existan
materiales publicados o que MinIO tenga un objeto determinado.

## Siete flujos

| Flujo | Ejecución y comprobación esperada |
| --- | --- |
| Catálogo | Abrir `/catalog`. La página consulta `GET /api/v1/catalog/filter` vía Gateway; los selectores académicos consultan además universidades, carreras, asignaturas y profesores. Con el seed local aparecen los datos de ejemplo. Verificar `200` y que la jerarquía se muestre en la interfaz. |
| Login mock | Abrir `/login`, ingresar un correo válido y una contraseña no vacía, y enviar. `POST /api/v1/auth/login` responde `200` con `accessToken` y `user`; el payload decodificado del token incluye `mock: true`. La UI muestra éxito, permanece en `/login` y no persiste el token. |
| Listado | Abrir `/library`. `GET /api/v1/materials?page=1&pageSize=20` responde `200` con `{ items, page, pageSize, total }`. Solo lista materiales `PUBLISHED`; con una base nueva sin publicaciones se espera una lista vacía. Tras preparar el material publicado de prueba, repetir la consulta y comprobar que aparece su ID. |
| Subida | Abrir `/materials/upload`, seleccionar universidad, carrera y asignatura activas, completar los campos, elegir un archivo admitido y revisar el resumen. Confirmar con **Subir material**. El formulario envía `POST /api/v1/materials` multipart y una creación válida responde `201`; la UI muestra éxito. Requiere bucket y credenciales MinIO, además del contexto de autor local descrito arriba. |
| Detalle | Desde un material publicado, abrir `/material/{materialId}`. `GET /api/v1/materials/{materialId}` devuelve `200`, metadatos e historial de versiones; la vista muestra el detalle y la versión actual. Un ID inexistente o no publicado devuelve `404`. |
| Descarga | En el detalle del material publicado de prueba, pulsar **Descargar material**. `GET /api/v1/materials/{materialId}/download` responde `200` con el contenido binario y `Content-Disposition`; el navegador inicia la descarga. Un material `LINK` no tiene archivo descargable. |
| Búsqueda | Abrir `/search`, buscar un término único del título del material publicado de prueba. `GET /api/v1/search?q=...` responde `200` con `results` y `context`; comprobar que `results` contiene el mismo ID. Search consulta Catalog y Material. La búsqueda directa al puerto `3005` no está habilitada para navegador cross-origin; usar Gateway. |

### Preparar datos para completar los siete flujos

En una base **local y descartable**, la subida del paso anterior crea un
material `PENDING_REVIEW`; no existe todavía una pantalla ni un endpoint de
moderación que lo publique. Por eso, listado, detalle, descarga y búsqueda
necesitan una publicación de prueba preparada expresamente:

1. Guarda el `id` devuelto por la respuesta `201` del flujo **Subida**. Confirma
   que `status` sea `PENDING_REVIEW` y que la respuesta no exponga `fileUrl`
   (su valor es `null`).
2. Desde `backend\material-service`, abre Prisma Studio contra el `.env` local:

   ```powershell
   npx prisma studio --schema prisma\schema.prisma
   ```

3. En la tabla `materials`, localiza ese ID y cambia únicamente su campo
   `status` de `PENDING_REVIEW` a `PUBLISHED`. No realices esta modificación en
   una base compartida o de producción: es una preparación de datos de prueba,
   no una validación del flujo real de moderación.
4. Comprueba en `material_versions` que ese `materialId` tenga una versión
   `versionNumber=1` y que el objeto correspondiente exista en el bucket
   privado `materials`. Si se creó con el flujo de subida y MinIO real, la
   versión y el objeto ya deberían existir.
5. Repite **Listado** y luego ejecuta **Detalle**, **Descarga** y **Búsqueda**
   con ese mismo ID. Para la búsqueda, usa una palabra distintiva del título.

### Registro de evidencia

La guía define el resultado esperado; no afirma que una corrida manual se haya
ejecutado en cada entorno. Para dejar evidencia de una ejecución concreta:

1. Abre las herramientas de desarrollo del navegador en **Network/Red** y
   conserva el registro. Activa *Preserve log* si vas a navegar entre rutas.
2. Ejecuta los siete flujos contra las URLs del entorno local y registra método,
   URL de Gateway, estado HTTP y el resultado observable. Para la subida,
   conserva el ID y el estado inicial; no adjuntes el archivo ni credenciales.
3. Guarda capturas de las pantallas Catálogo, Login, Listado, Subida, Detalle y
   Búsqueda; para Descarga, conserva también el archivo descargado y la
   respuesta con `Content-Disposition`. Oculta correos, tokens, cookies y
   cualquier otro dato sensible antes de compartir evidencia.
4. Completa este registro con datos reales de cada ejecución y adjunta las
   capturas/logs al PR o al sistema de seguimiento:

| Flujo | Petición/ruta que debe observarse en Gateway | Resultado esperado que registrar |
| --- | --- | --- |
| Catálogo | `GET /api/v1/catalog/filter` y llamadas del selector bajo `/api/v1/catalog/*` | `200`; universidades/carreras/asignaturas visibles |
| Login mock | `POST /api/v1/auth/login` | `200`; éxito visible; payload JWT con `mock: true`; sin persistencia de sesión |
| Listado | `GET /api/v1/materials?page=1&pageSize=20` | `200`; forma paginada; ID del fixture publicado presente (o lista vacía antes de prepararlo) |
| Subida | `POST /api/v1/materials` (`multipart/form-data`) | `201`; ID, `PENDING_REVIEW` y versión/archivo guardados |
| Detalle | `GET /api/v1/materials/{id}` | `200`; versión actual e historial del ID probado |
| Descarga | `GET /api/v1/materials/{id}/download` | `200`; `Content-Disposition` y archivo descargado |
| Búsqueda | `GET /api/v1/search?q={término}` | `200`; `results` contiene el ID probado y hay contexto académico |

**Datos de la corrida:** fecha/hora, sistema operativo, URL de Web, estado de
los cinco healthchecks y nombre/ID del material publicado de prueba:

```text
Fecha/hora:
Web:
Healthchecks (Gateway/Auth/Catalog/Material/Search):
Material ID:
Evidencia adjunta (capturas/log):
```

Para validar listado y búsqueda de extremo a extremo, debe existir al menos un
material `PUBLISHED`. Para detalle, usar el ID de una publicación; para
descarga, además debe tener una versión en PostgreSQL y el objeto
correspondiente en MinIO. La respuesta exitosa de subida no satisface estos
requisitos porque el material recién creado queda en revisión.

## Incidencias y diagnóstico reproducibles

- Si `docker compose up -d` informa que falta `MINIO_ROOT_USER` o
  `MINIO_ROOT_PASSWORD`, completar el `.env` de la raíz. Compose no inicia
  correctamente MinIO con variables vacías.
- Una subida sin contexto local de autor devuelve `401`, incluso después de
  completar el login mock: ambos contextos son independientes y el token mock
  no autoriza solicitudes.
- Una subida con MinIO inaccesible, bucket ausente o credenciales/permisos
  incorrectos no persiste el archivo; revisar el servicio MinIO y la
  configuración de Material. El bucket debe existir previamente.
- La creación `201` no hace aparecer el material en listado, detalle, descarga
  ni búsqueda mientras esté `PENDING_REVIEW`. No interpretar esta diferencia
  como fallo del POST.
- Un `502` del Gateway indica que el microservicio de destino no está
  disponible. Search necesita además que Catalog y Material estén activos; sus
  errores de dependencia pueden responder `502` o `503`.
