# ApuntesUCT en Kubero

Este despliegue conserva la arquitectura Web/Mobile → API Gateway → servicios.
Las imágenes se construyen desde el repositorio ApuntesUCT; no hace falta copiar
el código a otro repositorio llamado `ApuntesUCT-Kubero`.

## Componentes y límites actuales

| App Kubero sugerida | Imagen GHCR, prefijo `ghcr.io/cchelooo/` | Puerto | Health HTTP |
| --- | --- | --- | --- |
| `web` | `apuntesuct-kubero-web` | 8080 | `/health` |
| `gateway` | `apuntesuct-kubero-api-gateway` | 3000 | `/health` |
| `auth` | `apuntesuct-kubero-auth-service` | 3001 | `/api/v1/health` |
| `catalog` | `apuntesuct-kubero-catalog-service` | 3002 | `/health` |
| `material` | `apuntesuct-kubero-material-service` | 3003 | `/api/v1/health` |
| `search` | `apuntesuct-kubero-search-service` | 3005 | `/api/v1/health` |
| `minio` | `apuntesuct-kubero-minio` | 9000 | `/minio/health/live` |

Quality aún no tiene un paquete ejecutable y no se crea una imagen ficticia.
Search consulta Catalog y Material por HTTP; actualmente no necesita su propia DB.
Auth, Catalog y Material tienen bases independientes. MinIO almacena archivos privados.

La infraestructura no completa las funciones pendientes de la aplicación:

- Auth conserva el login mock y su JWT sin firma. No valida credenciales reales.
- Material solo admite el autor temporal con `NODE_ENV=development`. Las imágenes
  usan `NODE_ENV=production`: crear material/nuevas versiones sigue devolviendo
  `401` hasta integrar Auth. No habilitar el autor local en el hosting.
- El despliegue permite consultas y descargas de datos existentes. Una instalación
  vacía tendrá un catálogo y un listado vacíos; las migraciones no cargan una demo.
- La prueba de infraestructura inserta un fixture temporal directamente en la DB
  de Material y MinIO. Comprueba consultas/descargas, no una subida autenticada.

## Probar localmente

Requisitos: Docker con Compose v2 y Node.js 22. Desde la raíz del repositorio:

```bash
cp deploy/kubero/.env.example deploy/kubero/.env
docker compose --env-file deploy/kubero/.env -f deploy/kubero/compose.yaml up --build --wait --wait-timeout 180
node deploy/kubero/smoke.mjs
```

Web: `http://localhost:18080`. Gateway para Mobile local:
`http://localhost:13000/api/v1` (Android Emulator: `http://10.0.2.2:13000/api/v1`).
Los puertos son distintos a los del entorno de desarrollo habitual. Si se cambian
en `.env`, exportar también `WEB_PORT` y `GATEWAY_PORT` al ejecutar `smoke.mjs`.
`KUBERO_ENV_FILE` permite seleccionar otro archivo de variables para la prueba.
Usar una contraseña PostgreSQL alfanumérica en Compose; en una URI las contraseñas
con caracteres reservados deben codificarse como URL.

El Compose crea tres PostgreSQL, MinIO con bucket privado `materials`, cinco
servicios Nest y Web. Solo publica los puertos de Web/Gateway en loopback.
Sus volúmenes pertenecen al proyecto aislado `apuntesuct-kubero`.

La prueba comprueba rutas React, recursos estáticos, errores API sin fallback HTML,
login actual, Catalog, listado persistido, búsqueda textual, detalle, descarga de
bytes reales de MinIO y el rechazo de creación sin autor de producción. Recrea
PostgreSQL de Material y MinIO conservando los volúmenes y verifica que los datos
persisten. El fixture se elimina al terminar y no utiliza los volúmenes del
`docker-compose.yml` original. Ejecutar esta prueba solo en el Compose aislado.

Detener conservando datos:

```bash
docker compose --env-file deploy/kubero/.env -f deploy/kubero/compose.yaml down
```

Agregar `--volumes` elimina las bases y archivos de este entorno aislado.

## Construcción y publicación

`.github/workflows/kubero-images.yml` construye y arranca el stack en Linux AMD64
y ejecuta la misma prueba. En el PR y en la rama inicial `chore/kubero-deployment`
solo valida. Después del merge a `main`, publica las siete imágenes probadas en
GHCR con etiquetas `latest` y `sha-<SHA completo>`. También puede ejecutarse
manualmente; solo publica si se ejecuta sobre `main`.

Usa `GITHUB_TOKEN` con permiso `packages: write`; no necesita un PAT ni una clave
de Kubero para construir/publicar. Si el propietario del repositorio cambia, el
workflow adapta su prefijo en minúsculas. El nombre del repositorio no modifica
el prefijo estable `apuntesuct-kubero-` de las imágenes.

Cada subida se reintenta hasta tres veces, con 10 segundos entre intentos, para
fallos transitorios del registro. Si el último intento falla, la ejecución queda
fallida y no continúa publicando los siguientes servicios. Un permiso incorrecto
de GHCR debe corregirse; los reintentos no amplían el acceso del token.

Las imágenes backend incluyen los clientes Prisma generados para Linux, los
binarios compilados y los CLI fijados por el lockfile para ejecutar migraciones.
No incluyen archivos `.env`, código Mobile ni credenciales de una DB real.
Se conservan dependencias de herramientas para los CLI de migración; no son
imágenes mínimas. Backend se ejecuta con el usuario `node`.

MinIO Community se construye desde el commit oficial
`9e49d5e7a648f00e26f2246f4dc28e6b07f8c84a` (release
`RELEASE.2025-10-15T17-29-55Z`), con SHA-256 del archivo fuente verificado por
Docker. Esto evita depender de las imágenes oficiales retiradas de Docker Hub y
Quay. Se distribuyen la licencia AGPL y el código fuente exacto en
`/usr/share/licenses/minio/`. El repositorio upstream está archivado: fijar esta
versión permite reproducir la demo, no implica mantenimiento futuro de MinIO.

Auth/Catalog/Material ejecutan `prisma migrate deploy` antes de iniciar. No se usa
`migrate dev`, `db push` ni reset. Si falla una migración, el servicio no arranca:
revisar los logs y la conexión, sin borrar la base. Mantener una réplica por
servicio para el primer despliegue. `MIGRATE_ON_START=false` permite separar las
migraciones cuando exista un proceso de release propio.

## Configurar Kubero después del merge

1. Confirmar que el profesor incorporó al usuario al equipo correcto. Crear un
   pipeline, por ejemplo `apuntesuct`, con fase `production` y ese equipo.
2. Verificar que el workflow de `main` terminó correctamente. En GitHub → perfil
   → Packages → cada imagen → Package settings, hacer públicos los siete paquetes.
   Un repositorio público no vuelve públicos automáticamente sus paquetes.
3. Crear primero las apps internas `auth`, `catalog` y `material`, con addon
   PostgreSQL 17 en cada una: DB `auth_db`, `catalog_db`, `material_db`. Establecer
   usuario/contraseña propios y almacenamiento persistente. Guardar las variables
   indicadas abajo antes de esperar que el contenedor arranque.
4. Crear MinIO como app interna `minio`, puerto 9000, usando la imagen publicada
   `ghcr.io/cchelooo/apuntesuct-kubero-minio`. Conservar su comando predeterminado.
   Configurar `MINIO_ROOT_USER` y `MINIO_ROOT_PASSWORD`, y un volumen persistente
   montado en `/data` con clase disponible y `ReadWriteOnce`. Una réplica; elegir
   estrategia Recreate si la plataforma la ofrece para evitar escritores simultáneos.
   La imagen usa UID/GID 1000: el volumen debe permitir escritura a ese usuario
   (por ejemplo `fsGroup: 1000` en la configuración del pod).
   Health: `/minio/health/live`. Restringir el acceso externo a la API S3.
5. Crear un bucket privado `materials` con la consola interna o `mc`, y un usuario
   de servicio con lectura/escritura/borrado sobre ese bucket. Configurar sus
   credenciales en Material. No publicar las claves ni habilitar acceso anónimo.
6. Crear `search`, luego `gateway` y finalmente `web`, usando puertos/health de
   la tabla. Las imágenes se ingresan sin `:tag`; poner la etiqueta en su campo.
7. Publicar HTTPS solo para Web y Gateway, con subdominios disponibles del curso,
   por ejemplo `apuntesuct.inf.uct.cl` y `apuntesuct-api.inf.uct.cl`. Mantener los
   otros servicios sin dominio si la plataforma lo permite. La UI UCT
   `1.0.0-rc.20` exige un dominio en todas las apps: para las internas, configurar
   Networking → Whitelist Source Range como `127.0.0.1/32` y comprobar que el
   ingreso externo devuelve `403`. Esto restringe el ingress; no crea una
   NetworkPolicy entre pods. No habilitar acceso anónimo a MinIO.

El servicio Kubernetes `<app>-kuberoapp` escucha en **80**, aunque el contenedor
escuche en 3000, 3001, etc. Usar las URLs siguientes sin el puerto del contenedor;
MinIO también se consume por 80. Los addons PostgreSQL `<app>-postgres` sí usan
5432. Estos valores corresponden a Kubero; el Compose local conserva sus propios
nombres y puertos. Verificar el Service si otra instalación cambia estos valores.

Las apps deben compartir el namespace/fase del pipeline. Sustituir los DNS de
ejemplo si la instalación genera otros. Nunca usar `localhost` para comunicarse
entre contenedores. Configurar startup grace suficiente para migraciones (por
ejemplo 60 s), y readiness/liveness con las rutas de la tabla, en el puerto real.
En Seguridad, conservar la raíz de solo lectura y la escalada de privilegios
deshabilitada. Activar Run as Non-Root con UID/GID `1000` en backend/MinIO y `101`
en Web. PostgreSQL mantiene la configuración propia de su addon.

### Variables por app

Todas las imágenes backend traen `NODE_ENV=production`. Configurar **Container
Port** según la tabla: Kubero genera y reserva `PORT`, por lo que no debe añadirse
manualmente en Environment Variables. Las contraseñas son valores privados que
se cargan en Kubero.

**Auth**:

```dotenv
DATABASE_URL=postgresql://USUARIO:CLAVE_CODIFICADA@auth-postgres:5432/auth_db?schema=public
```

**Catalog**:

```dotenv
DATABASE_URL=postgresql://USUARIO:CLAVE_CODIFICADA@catalog-postgres:5432/catalog_db?schema=public
```

**Material** (su URL de Catalog sí incluye `/api/v1`):

```dotenv
DATABASE_URL=postgresql://USUARIO:CLAVE_CODIFICADA@material-postgres:5432/material_db?schema=public
CATALOG_SERVICE_URL=http://catalog-kuberoapp/api/v1
CATALOG_TIMEOUT_MS=5000
MINIO_ENDPOINT=minio-kuberoapp
MINIO_PORT=80
MINIO_USE_SSL=false
MINIO_BUCKET=materials
MINIO_ACCESS_KEY=CLAVE_DEL_USUARIO_DE_SERVICIO
MINIO_SECRET_KEY=SECRETO_DEL_USUARIO_DE_SERVICIO
MATERIAL_LOCAL_AUTHOR_ENABLED=false
```

**Search** (orígenes sin `/api/v1`):

```dotenv
CATALOG_SERVICE_URL=http://catalog-kuberoapp
MATERIAL_SERVICE_URL=http://material-kuberoapp
```

**Gateway** (orígenes sin `/api/v1`):

```dotenv
AUTH_SERVICE_URL=http://auth-kuberoapp
CATALOG_SERVICE_URL=http://catalog-kuberoapp
MATERIAL_SERVICE_URL=http://material-kuberoapp
SEARCH_SERVICE_URL=http://search-kuberoapp
```

Los enlaces del índice Swagger conservan sus valores locales por defecto. Para
consultar specs internas usar consola/port-forward; no exponer todos los servicios
solo para abrir ese índice. Los contratos fuente se mantienen en Backend.

**Web**:

```dotenv
GATEWAY_UPSTREAM=http://gateway-kuberoapp
```

Web incorpora `VITE_API_URL=/api/v1` al compilar. Nginx reenvía `/api/` al Gateway
interno y conserva la ruta, los errores y las descargas. `GATEWAY_UPSTREAM` se
sustituye al iniciar; cambiar el DNS no requiere recompilar React. Establecer
`VITE_API_URL` en Kubero no cambia un bundle ya construido.

La imagen Web admite el sistema de archivos raíz de solo lectura: escribe su
configuración generada, PID y archivos temporales exclusivamente en `/tmp`.
Kubero proporciona un `emptyDir` escribible en esa ruta; el Compose monta un
`tmpfs` y activa `read_only` para verificar la misma restricción. En Seguridad de
Kubero, mantener solo lectura y configurar Web como no root, UID/GID `101`
(usuario `nginx`). No montar un volumen sobre `/usr/share/nginx/html`.

**Mobile** se compila por separado; no es un contenedor Kubero:

```bash
flutter run --dart-define=API_GATEWAY_URL=https://apuntesuct-api.inf.uct.cl/api/v1
```

### Datos y actualización

Para cargar el catálogo de ejemplo, ejecutar una sola vez en la consola de
Catalog `node dist/prisma/seed.js`. Revisar primero el seed del repositorio:
escribe datos de demostración y no se ejecuta automáticamente en producción.

Para actualizar, seleccionar en las siete apps una etiqueta `sha-...` publicada
por una misma ejecución exitosa y redesplegar servicios antes de Web. Para volver
a una versión anterior, seleccionar su etiqueta; una imagen anterior no revierte
migraciones de base de datos. Con `latest`, usar descarga Always si está disponible
y redesplegar explícitamente después del build. Publicar una imagen no reinicia
por sí solo una app. El autodeploy se configura al conocer el pipeline y las apps;
este workflow no incorpora endpoints ni tokens de la demo de tareas.

Antes de dar el despliegue por validado, comprobar consultas desde Web y Mobile,
descargar un archivo real y confirmar persistencia tras un redespliegue de
PostgreSQL/MinIO. Un health verde no demuestra que Auth/subida estén terminados.

Referencias: [Primeros pasos](https://benjaminespinozafk.github.io/kubero-uct-docs/primeros-pasos.html),
[Pipeline y apps](https://benjaminespinozafk.github.io/kubero-uct-docs/despliegue.html),
[DB y variables](https://benjaminespinozafk.github.io/kubero-uct-docs/base-de-datos.html),
[Volúmenes](https://benjaminespinozafk.github.io/kubero-uct-docs/extras/volumenes.html),
[código oficial MinIO](https://github.com/minio/minio/tree/9e49d5e7a648f00e26f2246f4dc28e6b07f8c84a),
[migraciones Prisma](https://www.prisma.io/docs/orm/prisma-client/deployment/deploy-database-changes-with-prisma-migrate).
