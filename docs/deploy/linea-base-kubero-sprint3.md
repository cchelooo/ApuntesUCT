# Línea base de integración y prerrequisitos de Kubero — Sprint 3

**Issue:** [#451 — Establecer línea base de integración y prerrequisitos de Kubero](https://github.com/cchelooo/ApuntesUCT/issues/451)
**Plan:** S3-11 · **Hito:** Infraestructura
**Fecha de revisión documental:** 17 de noviembre de 2026
**Corte de la evidencia CI:** 15 de noviembre de 2026
**Commit de `main` validado por CI y publicado en GHCR:** [`93a00181f7318cda4dee63581f44f482d0dfff08`](https://github.com/cchelooo/ApuntesUCT/commit/93a00181f7318cda4dee63581f44f482d0dfff08)

## Comprobación operativa del 17 de noviembre de 2026

El usuario confirmó `https://apuntesuct.inf.uct.cl/` como dirección del entorno.
Se realizaron solicitudes GET reales por HTTPS, con validación de certificado,
el 17-11-2026 entre 21:56:01 y 21:56:07 UTC (18:56 en Chile).
Esta evidencia actualiza las limitaciones de acceso descritas en el corte anterior:
ya hay comprobación pública parcial, aunque todavía no acceso al panel.

| URL/ruta en el dominio confirmado | HTTP | Respuesta observada |
| --- | --- | --- |
| `/` | 200 | HTML de la SPA, con referencias a assets JS/CSS; no se ejecutó el navegador. |
| `/health` | 200 | Texto `ok`. |
| `/api/v1/health` | 200 | JSON con `status: ok`, `service: API Gateway`, timestamp `2026-11-17T21:56:06.868Z`. |
| `/api/v1/auth/health` | 200 | JSON con `status: ok`, `service: auth-service`, `database: connected`, timestamp `2026-11-17T21:56:07.357Z`. |

Se acredita respuesta pública de Web, tránsito por su proxy hasta Gateway y
respuesta de Auth con conexión a base de datos declarada por su healthcheck.
No se acredita login, autorización, salud de los demás servicios ni SHA desplegado.
El primer intento desde el sandbox no resolvió DNS; la consulta con salida de red
habilitada funcionó. No se clasifica ese fallo local como incidencia de Kubero.

El usuario confirmó el panel
`https://kubero.inf.uct.cl/pipeline/apuntesuct/apps`. La consulta del 17-11-2026
obtuvo HTTP 200 con el HTML inicial de la SPA Kubero, sin inventario embebido.
El endpoint de sesión usado por el cliente público, `/api/auth/session`, respondió
HTTP 401 (`Unauthorized`) desde esta conexión sin sesión. La sesión del navegador
del usuario no está compartida con las herramientas; no se obtuvo inventario
actual ni configuración del panel. Este 401 es control de acceso del panel y no
un fallo de los servicios de ApuntesUCT.

Las secciones siguientes completan el inventario configurado, variables y salud
interna con evidencia aportada por el usuario. Queda fuera de la evidencia
el digest efectivo de los pods; no se publicaron servicios privados.

## Alcance y conclusión ejecutiva

La revisión combina código y GitHub Actions, consultas HTTP públicas del agente,
capturas/configuración confirmada por el usuario y salida de la consola interna
de Gateway aportada por el usuario el 17-11-2026. No se crearon recursos ni se
cambió la arquitectura o configuración del despliegue. Las capturas permanecen
en la conversación; sus datos relevantes se transcriben en este documento.

Las siete apps vigentes tienen configurado el tag
`sha-67dc30086dc50f042849614d1cb9003719aef2c5`, con build/smoke/publicación CI
exitosos correlacionados y evidencia HTTP 200 de salud. Los valores no sensibles
y la presencia de variables sensibles fueron confirmados sin revelar secretos.
El agente no tiene sesión autenticada del panel; las capturas no permiten
verificar el digest efectivo de los pods ni todas sus réplicas.

Auth en ese SHA todavía es mock; el código más reciente y su CI del 15-11 ya
incluyen JWT RS256, pero son otra revisión. Quality existe en el repositorio y
sigue fuera del empaquetado Kubero revisado. Web responde por HTTPS y su proxy
alcanza Gateway/Auth. La autorización completa, persistencia y operaciones de
negocio no se deducen de los endpoints de salud. `client` y `server` se clasifican
como pruebas anteriores por indicación del usuario, con reparación diferida.

## 1. Aplicaciones, versiones, tags y dependencias

### Inventario observado en la captura del pipeline

Fuente: captura proporcionada en el chat el 13-11-2026, sin fecha de captura
visible. Pipeline `apuntesuct`, fase `production`, contexto `inClusterContext`.
Esta evidencia es histórica y debe contrastarse con el panel actual.

| App visible | Recursos y datos observables | Pendiente de verificar |
| --- | --- | --- |
| `auth` | Pod de aplicación y `auth-postgres-0`, ambos con métricas; addon PostgreSQL. | Tag/digest completo, salud y configuración actual. |
| `catalog` | Pod de aplicación y `catalog-postgres-0`, ambos con métricas; addon PostgreSQL. | Tag/digest completo, salud y configuración actual. |
| `material` | Pod de aplicación y `material-postgres-0`, ambos con métricas; addon PostgreSQL. | Tag/digest completo, salud, acceso a Catalog y MinIO. |
| `gateway` | Pod de aplicación con métricas. | Tag/digest completo, salud y conectividad a upstreams. |
| `search` | Pod de aplicación con métricas. | Tag/digest completo, salud y acceso a Catalog/Material. |
| `minio` | Pod de aplicación con métricas. | Tag/digest completo, salud, persistencia y bucket privado. |
| `web` | Pod de aplicación con métricas. | Tag/digest completo, salud, upstream y dominio/TLS. |
| `client` | App independiente con etiqueta `latest`; indica `Metrics unavailable`. | Función, imagen completa y estado del workload. No equivale por evidencia a `web`. |
| `server` | App independiente con etiqueta `latest`; solo aparece `server-postgres-0` con métricas y addon PostgreSQL. | Función, imagen y estado del workload de aplicación. No equivale por evidencia a `gateway`. |
| Quality | No aparece en el listado de la captura. | Confirmar inventario actual antes de concluir ausencia en el entorno. |

Las siete apps principales muestran etiquetas `sha-…` truncadas. No es posible
asociarlas al SHA de CI del 15 de noviembre. Métricas presentes no acreditan
readiness ni respuestas HTTP correctas; métricas ausentes tampoco prueban por sí
solas que una app esté caída. `client` y `server` deben investigarse como recursos
separados; no se propone eliminarlos ni reutilizarlos sin conocer su función.

### Configuración de `server` observada el 17-11-2026

Una nueva captura del formulario «Edit server in apuntesuct» confirma la app
`server` en la fase `production`, puerto de contenedor `3000`, dominio
`server.inf.uct.cl` y opción SSL activada. Es evidencia de los campos mostrados
por el panel; no acredita certificado válido, salud HTTP ni workload activo.
El usuario confirmó que la captura posterior de Deployment corresponde a esta
app: imagen `ghcr.io/cchelooo/apuntesuct-kubero-server`, tag `latest`. El puerto
3000 y el nombre de la imagen no permiten identificarla como el Gateway actual:
sigue pendiente conocer su función, origen de imagen y estado del workload,
y distinguirla de la app `gateway`.

### Capturas adicionales de configuración del 17-11-2026

- La captura `Captura desde 2026-11-17 19-06-24.png` muestra explícitamente
  `App Name: web`, puerto `8080`, dominio `apuntesuct.inf.uct.cl` y SSL activado.
  El dominio coincide con el comprobado por HTTP anteriormente.
- La captura `Captura desde 2026-11-17 19-06-56.png` muestra la sección Deployment:
  imagen `ghcr.io/cchelooo/apuntesuct-kubero-server`, tag `latest`. No muestra el
  nombre de la app ni la navegación; el usuario confirmó explícitamente que
  corresponde a `server`. Se registra como configuración mostrada, no como
  prueba de que el contenedor esté ejecutándose ni del digest descargado.
- Esa imagen no está entre las siete imágenes publicadas por el workflow
  revisado, que utiliza `apuntesuct-kubero-api-gateway` para Gateway y
  `apuntesuct-kubero-web` para Web. Esto requiere identificar el origen de la
  configuración; no demuestra que la imagen no exista ni autoriza a cambiarla.

### Imagen configurada de Web confirmada el 17-11-2026

La captura de Deployment enviada como respuesta a la solicitud de configuración
de `web` muestra:

- Imagen: `ghcr.io/cchelooo/apuntesuct-kubero-web`.
- Tag: `sha-67dc30086dc50f042849614d1cb9003719aef2c5`.
- El objeto Git local identifica el commit `67dc30086dc50f042849614d1cb9003719aef2c5`
  con fecha 29-10-2026 y asunto `Merge pull request #362 from cchelooo/fix/kubero-readonly-web`.

El tag configurado difiere de `sha-93a00181f7318cda4dee63581f44f482d0dfff08`,
correspondiente al run CI del 15-11 citado en este documento. Ese run no permite
atribuir sus resultados a la imagen configurada de Web. La sección 4 correlaciona CI
con `67dc3008…`; falta confirmar el digest del contenedor en ejecución: el formulario
acredita la configuración mostrada, no por sí solo la imagen efectivamente cargada.
Las comprobaciones HTTP públicas ya realizadas siguen siendo evidencia válida
de respuesta, pero no identifican la revisión del código. No se modificó el tag
ni se realizó un redespliegue.

### Gateway: configuración y salud pública del 17-11-2026

Las capturas del formulario de `gateway` confirman puerto de contenedor `3000`,
dominio `apuntesuct-api.inf.uct.cl`, SSL activado, imagen
`ghcr.io/cchelooo/apuntesuct-kubero-api-gateway` y tag
`sha-67dc30086dc50f042849614d1cb9003719aef2c5`. Coincide con el tag configurado
de Web; difiere del SHA de la evidencia CI del 15-11. La sección 4 verifica el run asociado; falta verificar el digest
del runtime.

Se consultó directamente el dominio por HTTPS con validación de certificado el
17-11-2026 entre 22:10:18 y 22:10:20 UTC (19:10 en Chile):

| Ruta en `https://apuntesuct-api.inf.uct.cl` | HTTP | Respuesta observada |
| --- | --- | --- |
| `/health` | 200 | `status: ok`, `service: API Gateway`, timestamp `2026-11-17T22:10:18.866Z`. |
| `/api/v1/health` | 200 | `status: ok`, `service: API Gateway`, timestamp `2026-11-17T22:10:19.360Z`. |
| `/api/v1/auth/health` | 200 | `status: ok`, `service: auth-service`, `database: connected`, timestamp `2026-11-17T22:10:20.156Z`. |

Esto acredita acceso público al Gateway y respuesta de Auth a través de su proxy.
No demuestra login/autorización ni salud de Catalog, Material, Search o MinIO.

### Configuración de `client` observada el 17-11-2026

La captura identifica explícitamente la app `client`, puerto de contenedor
`8080`, dominio `client.inf.uct.cl`, opción SSL desactivada e imagen
`ghcr.io/cchelooo/apuntesuct-kubero-client`. El campo Tag queda fuera de la
captura: la etiqueta `latest` solo está acreditada por la captura histórica del
listado, no reconfirmada en este formulario. Esta imagen tampoco pertenece al
conjunto de siete imágenes publicado por el workflow actual.

`client` y `server` son apps separadas de `web` y `gateway`, con imágenes de
nombres diferentes. Sigue pendiente establecer su función, procedencia y estado
del workload mediante detalles/logs del panel o confirmación del equipo. No se
concluye que sean obsoletas ni se propone eliminarlas basándose solo en nombres
o ausencia de métricas. SSL desactivado describe la opción del formulario; la
respuesta HTTP y eventuales redirecciones requieren comprobación independiente.

### Incidencia de arranque de `server`: logs aportados el 17-11-2026

El usuario identificó explícitamente el extracto como logs de `server`. Entre
19:08:29 y 19:08:59 del 17-11-2026 (hora mostrada por el visor, zona no incluida
en el extracto), el proceso registra 15 intentos de espera de base de datos y
termina con `No se pudo iniciar el servidor: Error: No se pudo conectar a la base de datos.`
El stack señala `waitForDatabase (/app/index.js:26:9)` y
`bootstrap (/app/index.js:73:3)`.

El visor presenta las mismas líneas para el contenedor actual y para
`previous container`, con identificador `7c7bddc4fb-mhvgx/web`. El sufijo `web`
es la etiqueta de contenedor del visor; no reasigna estos logs a la app `web`.
No se cuentan las líneas duplicadas como dos fallos independientes ni se infiere
un número de reinicios o estado `CrashLoopBackOff` sin ver el estado del pod.

Conclusión: hay evidencia de un arranque fallido de `server` por falta de conexión
a su base. No hay detalle del error subyacente para distinguir DNS, puerto,
credenciales, nombre de base, TLS o disponibilidad de PostgreSQL. La presencia
histórica de métricas de `server-postgres-0` no acredita conectividad desde la app.

Acción de diagnóstico pendiente: revisar estado/eventos de la app y su addon,
identificar las variables de conexión que consume esta imagen y contrastar host,
puerto y base con el addon, sin copiar contraseñas ni URLs con credenciales.
La función de `server` sigue sin confirmar: el usuario considera posible que sea
una prueba anterior, pero no lo sabe. No se debe modificar ni eliminar por esa
suposición. Esta incidencia no invalida los HTTP 200 observados en Web/Gateway/Auth.

### Clasificación acordada de `client` y `server`

Por indicación explícita del usuario el 17-11-2026, `client` y `server` se tratan
como aplicaciones de pruebas anteriores, separadas de la pila vigente
Web → Gateway → servicios. Esta clasificación procede del usuario; no es una
conclusión obtenida del contenido de las imágenes.

Se difiere su investigación y reparación: el usuario las atenderá posteriormente.
Se conserva como incidencia conocida el arranque fallido de `server` por conexión
a base de datos; no se declara resuelto. La disponibilidad de estas dos apps no
se utiliza como requisito de cierre para la pila vigente en este diagnóstico.
No se eliminaron apps, addons ni datos ni se modificó su configuración.
Esta decisión sustituye las solicitudes anteriores de aclarar su función y
continuar el diagnóstico de su conexión a base.

### Auth, Search, Catalog y Material: capturas y acceso externo

Las capturas del 17-11-2026 muestran estas imágenes bajo `ghcr.io/cchelooo/`,
todas con tag `sha-67dc30086dc50f042849614d1cb9003719aef2c5`:

| App | Imagen | Dominio | Puerto mostrado | SSL en formulario |
| --- | --- | --- | --- | --- |
| `auth` | `apuntesuct-kubero-auth-service` | `auth-apuntesuct.inf.uct.cl` | 3001 | Desactivado |
| `search` | `apuntesuct-kubero-search-service` | `search-apuntesuct.inf.uct.cl` | 3005 (texto superpuesto en captura) | Desactivado |
| `catalog` | `apuntesuct-kubero-catalog-service` | `catalog-apuntesuct.inf.uct.cl` | 3002 (texto superpuesto en captura) | Desactivado |
| `material` | `apuntesuct-kubero-material-service` | `material-apuntesuct.inf.uct.cl` | 3003 (texto superpuesto en captura) | Desactivado |

Los puertos con texto superpuesto se leen en la captura y coinciden con Compose;
queda pendiente reconfirmarlos sin superposición. La configuración mostrada no
identifica por sí sola el digest del contenedor en ejecución.

El 17-11-2026 a las 22:17:30 UTC (19:17 en Chile) se consultaron por HTTP
`/api/v1/health` en Auth, Search y Material, y `/health` en Catalog. Las cuatro
consultas terminaron en HTTPS en el mismo dominio/ruta y devolvieron **403** con
página `Forbidden` de Nginx. Por tanto, pese al selector SSL desactivado, se
observa redirección a HTTPS. El acceso externo está denegado desde esta conexión;
no se atribuye el 403 al healthcheck de cada servicio ni se declara que estén
caídos. Es compatible con restricciones de ingress, cuya configuración exacta
no se inspeccionó. Auth ya respondió 200 con DB conectada por el Gateway.

La sección 2 registra las consultas internas posteriores: Catalog, Material
y Search respondieron HTTP 200 desde Gateway. No desactivar restricciones ni publicar servicios privados
para efectuar la comprobación.

**Diferencia funcional de Auth:** el controlador Auth en el objeto Git
`67dc30086dc50f042849614d1cb9003719aef2c5` declara login mock y JWT sin firma
(`alg: none`). La implementación RS256 descrita para el código más reciente no
puede atribuirse al tag configurado en Kubero. Es un prerrequisito pendiente
correlacionar la imagen en ejecución y planificar la promoción de Auth real con
sus secretos/configuración; no se ejecutó login ni se cambió el despliegue.

### MinIO: configuración y acceso externo del 17-11-2026

La captura confirma app `minio`, puerto `9000`, dominio
`minio-apuntesuct.inf.uct.cl`, SSL desactivado en el formulario, imagen
`ghcr.io/cchelooo/apuntesuct-kubero-minio` y tag
`sha-67dc30086dc50f042849614d1cb9003719aef2c5`.
Con ello quedan documentados los tags configurados de las siete apps vigentes:
Web, Gateway, Auth, Catalog, Material, Search y MinIO comparten ese SHA.
No se ha comprobado el digest de los contenedores en ejecución.

El 17-11-2026 a las 22:19 UTC (19:19 en Chile), GET HTTP a
`minio-apuntesuct.inf.uct.cl/minio/health/live` terminó en HTTPS en la misma ruta
y respondió **403**, página `Forbidden` de Nginx. Se acredita denegación de acceso
externo desde esta conexión, no fallo del servicio MinIO. La salud interna posterior respondió HTTP 200 (sección 2). Quedan pendientes
pruebas de persistencia y permisos de bucket; las variables de acceso de
Material se revisaron según la sección 3. No se consultaron objetos ni se cambiaron permisos.

### Artefactos del repositorio y CI

Esta tabla describe el corte de código/CI del 15-11, no las versiones de
bibliotecas de las imágenes configuradas con el SHA anterior.

La versión es la declarada en el `package.json`; no representa necesariamente una
versión desplegada. El workflow de imágenes publica artefactos para el commit
`93a0018` con el tag inmutable `sha-93a00181f7318cda4dee63581f44f482d0dfff08`
y el tag mutable `latest`. El run de publicación concluyó correctamente. No hay
evidencia de que Kubero esté configurado para consumir dichos tags.

| App / rol operativo | Versión y tecnología declaradas | Imagen y tag publicados para el commit validado | Puerto y dependencias principales | Estado real en Kubero |
| --- | --- | --- | --- | --- |
| `web` | `web@0.0.0`; SPA React `^19.2.8`, Vite `^8.2.2`; Nginx sirve los artefactos estáticos. | `ghcr.io/cchelooo/apuntesuct-kubero-web:sha-93a00181f7318cda4dee63581f44f482d0dfff08` y `:latest`. | Contenedor `8080`. `GATEWAY_UPSTREAM` dirige Nginx al Gateway por HTTP interno; las llamadas del cliente usan `/api/v1`. | Panel: tag `sha-67dc30086dc50f042849614d1cb9003719aef2c5`, distinto del publicado aquí. HTTP público 200 el 17-11; digest del runtime pendiente. |
| `gateway` (`api-gateway`) | `api-gateway@0.0.1`; NestJS `11.2.7`, Node.js `22` en CI. | `ghcr.io/cchelooo/apuntesuct-kubero-api-gateway:sha-93a00181f7318cda4dee63581f44f482d0dfff08` y `:latest`. | Contenedor `3000`. Enruta solicitudes HTTP internas a Auth, Catalog, Material y Search; no declara una base propia en el Compose Kubero. | Panel: tag `sha-67dc30086dc50f042849614d1cb9003719aef2c5`. Salud pública directa HTTP 200 el 17-11; digest del runtime pendiente. |
| `auth-service` | `auth-service@0.0.1`; NestJS `11.2.7`, Prisma `6.12.0`. El flujo de registro/login emite JWT RS256. | `ghcr.io/cchelooo/apuntesuct-kubero-auth-service:sha-93a00181f7318cda4dee63581f44f482d0dfff08` y `:latest`. | Contenedor `3001`; PostgreSQL dedicado (`auth_db`). Gateway consume su API. La clave privada se monta como secret, no se incorpora a la imagen. | Panel: tag `sha-67dc30086dc50f042849614d1cb9003719aef2c5`; salud HTTP 200 el 17-11. Digest runtime pendiente. |
| `catalog-service` | `catalog-service@0.0.1`; NestJS `11.2.7`, Prisma `6.12.0`. | `ghcr.io/cchelooo/apuntesuct-kubero-catalog-service:sha-93a00181f7318cda4dee63581f44f482d0dfff08` y `:latest`. | Contenedor `3002`; PostgreSQL dedicado (`catalog_db`). Es consultado por Gateway, Material y Search. | Panel: tag `sha-67dc30086dc50f042849614d1cb9003719aef2c5`; salud HTTP 200 el 17-11. Digest runtime pendiente. |
| `material-service` | `material-service@0.0.1`; NestJS `11.2.7`, Prisma `6.12.0`. | `ghcr.io/cchelooo/apuntesuct-kubero-material-service:sha-93a00181f7318cda4dee63581f44f482d0dfff08` y `:latest`. | Contenedor `3003`; PostgreSQL dedicado (`material_db`), Catalog por HTTP y MinIO para objetos/binarios. | Panel: tag `sha-67dc30086dc50f042849614d1cb9003719aef2c5`; salud HTTP 200 el 17-11. Digest runtime pendiente. |
| `search-service` | `search-service@0.0.1`; NestJS `11.2.7`. | `ghcr.io/cchelooo/apuntesuct-kubero-search-service:sha-93a00181f7318cda4dee63581f44f482d0dfff08` y `:latest`. | Contenedor `3005`; consulta Catalog y Material por HTTP. No usa una base propia en el Compose Kubero revisado. | Panel: tag `sha-67dc30086dc50f042849614d1cb9003719aef2c5`; salud HTTP 200 el 17-11. Digest runtime pendiente. |
| `quality-service` | `quality-service@0.0.1`; workspace NestJS, Prisma y control de salud con persistencia. | **Sin imagen/tag Kubero publicado** por el workflow actual. | El código espera configuración y una base propia para Quality; contrato de salud `/health`. No está cableado al Gateway ni a Compose. | Pendiente de empaquetar e integrar. |

El prefijo de imagen se adapta al propietario del repositorio en el workflow; los
tags arriba reflejan el propietario observado en el run de referencia. Los
servicios del Compose usan nombres DNS internos (`auth`, `catalog`, `material`,
`search`, `gateway`, `minio`), no direcciones públicas. Si las apps se gestionan
como unidades separadas en Kubero, se debe confirmar que su red y DNS interno
resuelven los nombres equivalentes antes de promocionar el despliegue.

El Compose de referencia declara tres PostgreSQL independientes (Auth, Catalog y
Material) y MinIO con bucket privado `materials`. `minio-init` crea el bucket;
Material usa Catalog y MinIO; Search obtiene datos desde Catalog y Material.
Quality no tiene base ni aplicación declarada en ese Compose, aunque su código
ya contempla persistencia. No asumir que una base Quality local implica que
exista en Kubero.

## 2. Salud y comprobación de endpoints

### Comprobación interna desde Gateway: 17-11-2026

Fuente: salida de la consola de Gateway ejecutada por el usuario y compartida en
la conversación. Las solicitudes GET se realizaron con Node `fetch`, sin cambiar
configuración ni datos, entre 22:31:12.982 y 22:31:13.079 UTC (19:31 en Chile).

| Servicio | URL interna consultada | HTTP | Respuesta observada |
| --- | --- | --- | --- |
| Catalog | `http://catalog-kuberoapp/health` | 200 | `status: ok`, `service: catalog-service`, timestamp `2026-11-17T22:31:12.897Z`. |
| Material | `http://material-kuberoapp/api/v1/health` | 200 | `status: ok`, `service: material-service`, timestamp `2026-11-17T22:31:13.004Z`. |
| Search | `http://search-kuberoapp/api/v1/health` | 200 | `status: ok`, `info: {}`, `error: {}`, `details: {}`. |
| MinIO | `http://minio-kuberoapp/minio/health/live` | 200 | Cuerpo vacío. |

Se acredita resolución de los nombres internos y conectividad HTTP desde el pod
Gateway a los cuatro destinos. Junto con las comprobaciones públicas anteriores,
las siete apps vigentes cuentan con evidencia HTTP de salud. Los 403 externos
no impidieron estas consultas internas. No se infiere de estos healthchecks
persistencia, permisos de bucket, conectividad desde otros pods ni funcionamiento
de todas las operaciones de dominio. La procedencia de esta evidencia es la
salida aportada por el usuario, no una conexión directa del agente al pod.

### Evidencia histórica de CI (otra revisión)

**Fecha de evidencia automatizada:** 15 de noviembre de 2026, entre `17:15Z` y
`17:20Z` (14:15–14:20 UTC−03). El job `images` del run
[`43740083104`](https://github.com/cchelooo/ApuntesUCT/actions/runs/43740083104)
construyó y levantó un Compose efímero, esperó sus healthchecks y completó
[`deploy/kubero/smoke.mjs`](../../deploy/kubero/smoke.mjs). No es una medición
del Kubero compartido. El smoke no conserva cuerpos HTTP como artefacto; los
payloads descritos abajo son la estructura definida por los controladores, no
una captura de una respuesta en vivo.

| Aplicación | Endpoint y evidencia al 15-11-2026 | Código HTTP que permite afirmar la evidencia | Resultado / estructura del payload |
| --- | --- | --- | --- |
| Web | `GET /health`; el smoke lo solicita con expectativa explícita `200`. | **200** en el Compose efímero. | Texto plano `ok` (Nginx). No valida API ni dependencias. |
| Gateway | `GET /health` y `GET /api/v1/health`; el smoke espera `200` en ambos. | **200** en el Compose efímero. | JSON `{ "status": "ok", "service": "API Gateway", "timestamp": "<ISO-8601>" }`. Es una comprobación de disponibilidad del proceso, no de sus upstreams. |
| Auth | `GET /api/v1/health`; healthcheck de Compose exitoso. El smoke también obtuvo el status esperado `200` del proxy `/api/v1/auth/health`. | **2xx** para el endpoint directo según healthcheck (este no registra el status exacto); **200** para el endpoint probado por Gateway/Web. | `{ "status": "ok", "service": "auth-service", "database": "connected", "timestamp": "<ISO-8601>" }`; si PostgreSQL no está disponible, el servicio responde `503` con estado `unavailable`/`disconnected`. |
| Catalog | `GET /health`; healthcheck de Compose exitoso. | **2xx**; el healthcheck solo comprueba `response.ok`, no conserva el status exacto. | `{ "status": "ok", "service": "catalog-service", "timestamp": "<ISO-8601>" }`. Es un chequeo del servicio, no de PostgreSQL. |
| Material | `GET /api/v1/health`; healthcheck de Compose exitoso. | **2xx**; el healthcheck solo comprueba `response.ok`. | `{ "status": "ok", "service": "material-service", "timestamp": "<ISO-8601>" }`. No acredita por sí solo Catalog, MinIO ni autorización. |
| Search | `GET /api/v1/health`; healthcheck de Compose exitoso. | **2xx**; el healthcheck solo comprueba `response.ok`. | Terminus: `{ "status": "ok", "info": {}, "error": {}, "details": {} }` cuando no registra checks fallidos. |
| Quality | Hay controlador de salud `/health` en el código; no existe servicio Quality en el Compose de Kubero ni en el smoke de imágenes. | **Sin solicitud y sin código HTTP verificado.** | El código define `status`, `service` y `database`; no se debe registrar como endpoint disponible ni saludable hasta desplegarlo y probarlo. |

Los healthchecks backend de Compose prueban HTTP y éxito 2xx; no todos son
chequeos profundos de dependencias. MinIO tiene una comprobación de vida
`/minio/health/live` en el smoke, pero la respuesta no se registra como una
medición del Kubero existente. La comprobación operativa independiente se
registra al inicio de esta sección, y la correlación CI en la sección 4.

## 3. Variables de entorno y comunicación entre servicios

### Evidencia del panel: Search, Auth, Catalog y MinIO, 17-11-2026

El usuario confirmó que Search tiene `CATALOG_SERVICE_URL=http://catalog-kuberoapp`
y `MATERIAL_SERVICE_URL=http://material-kuberoapp`; que Auth y Catalog tienen
cada uno `DATABASE_URL` definida; y que MinIO tiene definidas `MINIO_ROOT_USER`
y `MINIO_ROOT_PASSWORD`. No se solicitaron ni registraron valores sensibles.

Con las confirmaciones de Web, Gateway y Material queda cubierta la revisión de
presencia y valores no sensibles solicitados para las siete apps configuradas.
Estas confirmaciones del usuario no sustituyen comprobaciones de las variables
efectivas del proceso, permisos de almacenamiento, persistencia o conectividad.
Las variables de JWT de Auth real se mantienen como prerrequisito de una futura
promoción, pues el tag actualmente configurado corresponde a código mock.


### Evidencia del panel: Material, 17-11-2026

El usuario confirmó que los valores revisados en el panel coinciden con:

| Variable | Valor confirmado por el usuario |
| --- | --- |
| `CATALOG_SERVICE_URL` | `http://catalog-kuberoapp/api/v1` |
| `MINIO_ENDPOINT` | `minio-kuberoapp` |
| `MINIO_PORT` | `80` |
| `MINIO_USE_SSL` | `false` |
| `MINIO_BUCKET` | `materials` |
| `MATERIAL_LOCAL_AUTHOR_ENABLED` | `false` |

También confirmó que `DATABASE_URL`, `MINIO_ACCESS_KEY` y `MINIO_SECRET_KEY`
están definidas. No se solicitaron ni registraron sus valores. Esto acredita
presencia y configuración declarada, no validez de credenciales, permisos del
bucket, conectividad a PostgreSQL/MinIO/Catalog ni carga efectiva en el runtime.
El autor temporal está desactivado en la configuración revisada; la integración
de identidad real sigue siendo un prerrequisito para la revisión configurada.


### Evidencia del panel: Web, 17-11-2026

El usuario confirmó explícitamente que `GATEWAY_UPSTREAM` coincide con
`http://gateway-kuberoapp`. El valor utiliza DNS interno y HTTP 80, coherente
con la configuración documentada. La confirmación corresponde al valor revisado
en el panel; además, las consultas públicas anteriores desde Web a la salud de
Gateway y Auth devolvieron HTTP 200. No se modificó la variable.


### Evidencia del panel: Gateway, 17-11-2026

La captura aportada en respuesta a la revisión de Gateway muestra
`AUTH_SERVICE_URL`, `CATALOG_SERVICE_URL`, `MATERIAL_SERVICE_URL` y
`SEARCH_SERVICE_URL`, todas con valores enmascarados. Se confirma su presencia
en el formulario; no se verifican contenido, DNS, puerto, prefijo de ruta ni
aplicación efectiva al contenedor. No se registraron valores secretos.
La respuesta previa de Auth vía Gateway acredita esa ruta en el momento de la
consulta, pero no revela el valor de `AUTH_SERVICE_URL`.

Tras revisar los valores, el usuario confirmó explícitamente el 17-11-2026
que las cuatro variables coinciden con los destinos siguientes:

| Variable | Valor confirmado por el usuario |
| --- | --- |
| `AUTH_SERVICE_URL` | `http://auth-kuberoapp` |
| `CATALOG_SERVICE_URL` | `http://catalog-kuberoapp` |
| `MATERIAL_SERVICE_URL` | `http://material-kuberoapp` |
| `SEARCH_SERVICE_URL` | `http://search-kuberoapp` |

Son orígenes internos sin `/api/v1` ni puerto explícito (HTTP 80), coherentes con
el README de esta instalación. La confirmación acredita los valores revisados
en el panel; no comprueba por sí sola DNS, disponibilidad de cada upstream ni
variables efectivas del proceso. Auth vía Gateway sí tiene evidencia HTTP 200;
Catalog, Material y Search también respondieron HTTP 200 desde Gateway
en la consulta interna registrada en la sección 2.


| Grupo / variables relevantes | Uso técnico | Requisito y manejo seguro |
| --- | --- | --- |
| `PORT`, `HEALTH_PATH` | Puerto de escucha y ruta usada por healthcheck de los servicios del Compose. | Configurar el puerto interno de cada app en Kubero; no confundirlo con `WEB_PORT`/`GATEWAY_PORT`, que publican puertos locales del Compose. |
| `GATEWAY_UPSTREAM` | Upstream de Nginx para `/api/`; en la red Compose apunta al Gateway. | En el entorno existente usar la dirección interna resoluble del Gateway y preservar los paths `/api/v1`. |
| `AUTH_SERVICE_URL`, `CATALOG_SERVICE_URL`, `MATERIAL_SERVICE_URL`, `SEARCH_SERVICE_URL` | URLs HTTP del Gateway hacia sus servicios backend. | Mantener comunicación privada entre apps y validar DNS, puerto, timeouts y rutas. No publicar los servicios internos innecesariamente. |
| `DATABASE_URL` | Conexiones Prisma de Auth, Catalog y Material; Quality también prevé conexión propia en su código. | Definir un valor distinto por servicio/base; almacenar como secreto de Kubero y evitar imprimirlo en logs. Codificar correctamente caracteres reservados en URI. |
| `POSTGRES_PASSWORD` | Contraseña exigida por Compose para bases locales/efímeras. | En Kubero utilizar secreto aleatorio gestionado por el entorno; no reutilizar valores de muestra ni del Compose local. |
| `JWT_PRIVATE_KEY_PATH`, `JWT_ISSUER`, `JWT_AUDIENCE` | Firma y validación de tokens Auth. El Compose monta la clave privada desde un archivo secret externo solo en Auth. | Guardar la clave privada como secret; definir issuer/audience compatibles con los validadores; acordar rotación y no copiar la clave a imágenes, logs o documentación. |
| `MINIO_ENDPOINT`, `MINIO_PORT`, `MINIO_USE_SSL`, `MINIO_BUCKET`, `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY` | Conexión Material → MinIO y bucket de archivos. | Confirmar nombre DNS interno, TLS, política de acceso mínimo y bucket privado. Evitar credenciales administrativas de MinIO en Material. |
| `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD` | Bootstrap local/efímero de MinIO y creación inicial del bucket. | No exponerlas ni usarlas como credenciales rutinarias de producción. |
| `MATERIAL_LOCAL_AUTHOR_ENABLED` | Controla el autor temporal local de Material. | Mantenerlo desactivado en producción; no usarlo como sustituto de identidad/autorización real. |
| `VITE_API_URL` y variables `VITE_*` | Configuración incorporada al bundle en build de Vite. El smoke observa URL relativa `/api/v1`. | El bundle es público: nunca inyectar contraseñas, tokens, claves privadas u otros secretos en variables `VITE_*`. |

En Compose, el tráfico Web → Gateway y Gateway → servicios circula por HTTP en
la red interna. Material → Catalog y Search → Catalog/Material también son
llamadas HTTP internas. Auth firma tokens; el Gateway y los servicios que
protegen rutas deben validar firma y claims en el lado servidor. La Web no debe
conectarse directamente a bases de datos, MinIO ni endpoints privados.

El workflow de imágenes genera una clave RSA efímera para CI fuera del contexto
Docker, la suministra a Auth como secret temporal y la elimina al finalizar. No
se publica ni se incorpora a las imágenes. Los valores del archivo
`deploy/kubero/.env.example` son solo plantilla local; no son credenciales
productivas. Como incidencia, `docker-compose.yml` raíz contiene credenciales de
base de datos escritas literalmente: no se reproducen aquí. Deben externalizarse
en el cambio correspondiente y rotarse si se reutilizaron fuera de desarrollo.

## 4. Pruebas automatizadas y workflows CI/CD

### CI correlacionado con el tag configurado

El 17-11-2026 se consultó la API pública de Actions filtrando por el SHA completo
`67dc30086dc50f042849614d1cb9003719aef2c5`: devolvió un run,
[Kubero images #40934091597](https://github.com/cchelooo/ApuntesUCT/actions/runs/40934091597),
creado el 29-10-2026 a las 18:47:22 UTC, evento `push`, estado `completed`,
conclusión `success`. Se consultaron además sus jobs mediante el conector GitHub:
el job `images` y los pasos `Build and start isolated stack`,
`Check Web, Gateway and services` y `Publish tested images` finalizaron en
`success`.

Esto correlaciona build, smoke y publicación con el SHA configurado en las siete
apps. No identifica el digest efectivo de los pods ni acredita Auth real: ese
commit contiene el flujo mock. La consulta no devolvió un run `PR tests` para
ese SHA exacto; los runs recientes de la tabla siguiente son evidencia de otra
revisión y no se atribuyen al tag configurado. Esta comprobación resuelve la
correlación CI pendiente mencionada en las notas anteriores.


### Estado observado

El 17-11-2026 se volvieron a consultar los jobs de ambos runs mediante la API de
GitHub: los 11 jobs devueltos de `PR tests` finalizaron en `success`; el job
`images` también, incluidos build, smoke y publicación. Esta consulta confirma
los runs históricos citados; no acredita el último CI de `main` ni el SHA
actualmente desplegado en Kubero.

| Evidencia | Resultado | Alcance / limitación |
| --- | --- | --- |
| [PR tests del PR #506, run `43619110816`](https://github.com/cchelooo/ApuntesUCT/actions/runs/43619110816), 14-11-2026 | Los 11 jobs devueltos por la consulta del 17-11-2026 concluyeron `success`: backend, E2E de Gateway/Auth/Catalog/Material, integración Material, regresión browser Web/Gateway, lint/formato Web, pruebas Web unitarias/integración y Mobile. | Corresponde a los checks previos al merge del cambio Auth que precede al SHA integrado; es evidencia de la revisión del código, no una prueba ejecutada por `PR tests` sobre el commit de merge. |
| [Kubero images en `main`, run `43740083104`](https://github.com/cchelooo/ApuntesUCT/actions/runs/43740083104), commit `93a0018`, 15-11-2026 | `Build and start isolated stack`, `Check Web, Gateway and services` y `Publish tested images` concluyeron `success`. | Valida build, healthchecks y smoke en CI y publica tags GHCR. No despliega ni verifica apps del Kubero compartido. |

El workflow `PR tests` (`.github/workflows/pr-tests.yml`) ejecuta Node.js 22,
tests de todos los workspaces backend con cobertura, validación de contratos
OpenAPI/Postman, pruebas Web con Vitest, lint/formato Web, pruebas Flutter y
matriz E2E para Gateway, Auth, Catalog y Material con PostgreSQL efímero.
Incluye integración Material y regresión browser Web/Gateway. Quality participa
en los tests backend unitarios porque está declarado como workspace y define
`test:ci`, pero no tiene job E2E/integración propio en la matriz. Search tampoco
tiene job E2E dedicado en esa matriz.

El workflow `Kubero images` (`.github/workflows/kubero-images.yml`) construye y
levanta el Compose aislado, espera healthchecks, ejecuta el smoke y, en ejecuciones sobre `main` que no sean PR (push o ejecución manual), etiqueta y publica siete imágenes en GHCR. La lista publicada incluye
Web, Gateway, Auth, Catalog, Material, Search y MinIO; **no incluye Quality**.
No hay en este workflow una operación de despliegue a Kubero ni una confirmación
de actualización de sus apps.

El smoke prueba la ruta SPA y assets, salud de Web/Gateway, rutas API, registro y
login real vía Gateway/proxy Web y firma/claims RS256. También valida consultas y
descarga con fixtures temporales de Material. No sustituye una prueba de
autorización HTTP en todas las rutas protegidas ni acredita la subida funcional
por un usuario en el Kubero productivo. Las pruebas Flutter ejecutan
`flutter test`; no son una prueba instrumentada en dispositivo real.

## 5. Problemas detectados y prerrequisitos para Sprint 3

| Prioridad | Estado / problema | Prerrequisito y evidencia de salida |
| --- | --- | --- |
| Alta | Las capturas del 17-11 acreditan imágenes/tags y dominios de las siete apps vigentes. Hay salud pública de Web/Gateway/Auth y acceso directo denegado a los servicios internos; también se verificaron variables y salud interna. Faltan digests efectivos, réplicas y pruebas funcionales completas. | En el seguimiento del despliegue, registrar digests y réplicas y probar operaciones entre dependencias. Conservar la evidencia HTTP y configuración ya registrada sin atribuirle cobertura funcional completa. |
| Alta | Auth en el corte CI reciente emite JWT RS256, pero el código asociado al tag configurado en Kubero todavía es mock. El smoke reciente valida firma y claims de otra revisión. Sin embargo, la documentación de despliegue indica que la validación JWT de rutas protegidas de dominio sigue pendiente; salud/login exitosos no equivalen a autorización integrada. | Enlazar validadores en Gateway/servicios según el contrato vigente; comprobar token ausente, inválido, expirado y rol insuficiente con tests E2E; completar Web → Gateway → Auth → Material. Mantener claves fuera de repositorio, cliente y logs, y documentar rotación. |
| Alta | Quality existe como workspace y tiene implementación/contrato de salud, pero no se empaqueta ni ejecuta en el despliegue Kubero: falta imagen, servicio Compose, variables operativas, healthcheck de contenedor y wiring/ruta Gateway. La base Quality no está declarada en el Compose Kubero. | Acordar contrato API, consumidores, autorización, necesidad/esquema de persistencia y ownership. Después añadir Quality al pipeline y al entorno existente con configuración, migraciones, healthcheck, smoke, pruebas E2E e instrucciones de rollback. No crear un entorno paralelo. |
| Alta | Los tags publicados `sha-93a0018…` y `latest` acreditan publicación, no que Kubero los haya promovido. `latest` además es mutable. | Inspeccionar el tag/digest configurado en cada app y desplegar/promover explícitamente en Kubero con un tag inmutable, ventana de verificación y tag previo de rollback. |
| Media | Web responde por HTTPS y enruta salud hacia Gateway/Auth. Su upstream fue confirmado; falta probar comportamiento autenticado; la regresión CI citada corresponde a otra revisión. | Conservar la configuración confirmada y validar sesión, expiración, logout, respuestas `401` y errores reales contra el Gateway desplegado, sin datos/secretos en el bundle. |
| Alta | El Compose raíz versiona credenciales de DB en texto plano y no debe confundirse con la topología Kubero. | Externalizar los valores y rotar los que hayan sido reutilizados, sin propagarlos a logs, imágenes, documentación ni variables del cliente. |
| Media | No hay job E2E dedicado para Quality ni Search en la matriz PR; la cobertura de salud/funcionalidad de esos servicios depende del workspace y del smoke de pila, respectivamente. | Añadir suites orientadas a los contratos de Search y Quality antes de declarar integración Sprint 3 completa. |

**Prerrequisitos para la integración posterior (no requisitos de implementación de la #451):** CI verde para el SHA promovido; imagen identificada
por SHA/digest; secretos gestionados fuera del repositorio; comunicación interna
verificada; health HTTP consultado en el Kubero existente con fecha/status; Auth
probado con autorización real; Quality construido e integrado solo tras cerrar
contrato/persistencia; Web comprobada contra el Gateway y dominio/TLS configurados.

## 6. Cierre de la #451

Inventario configurado, variables y salud HTTP cuentan con evidencia operativa.
El run de build/smoke/publicación del SHA configurado fue verificado.
Los límites pendientes (digest runtime, persistencia y funcionalidad completa)
se mantienen explícitos; no se declara integración funcional completa. No exige implementar Auth o
Quality ni desplegar versiones nuevas para completar este diagnóstico.

| Criterio | Evidencia y pendiente |
| --- | --- |
| Estado de componentes desplegados | Imágenes/tags, dominios y puertos registrados para las siete apps vigentes; digests y estado completo del runtime pendientes; `client`/`server` clasificados por el usuario como pruebas anteriores. |
| Servicios disponibles, pendientes y dependencias | Dependencias documentadas; salud HTTP 200 de las siete apps y restricciones externas registradas. Funcionalidad completa y persistencia no inferidas de salud. |
| Endpoints de salud accesibles | Siete apps con salud HTTP 200 el 17-11: Web/Gateway/Auth por acceso público y Catalog/Material/Search/MinIO desde la consola de Gateway, según salida aportada por el usuario. |
| Variables sin secretos | Presencia y valores no sensibles revisados mediante captura y confirmaciones del usuario para las siete apps. No se revelaron secretos; validez de credenciales y configuración efectiva del proceso no comprobadas. |
| Pruebas y workflows | Run #40934091597 exitoso correlacionado con el SHA configurado; runs recientes diferenciados. No se encontró PR tests para ese SHA exacto en la consulta. |
| Prerrequisitos Auth, Quality y Web | Documentados en la sección 5; su implementación corresponde a tareas posteriores. |
| Problemas y acciones | Registrados, incluidas las apps de pruebas anteriores, cuya reparación se difiere por indicación del usuario. |
| Diagnóstico sobre infraestructura existente | Documento actualizado; completar evidencia operativa antes de cerrar. |

### Referencias

- [`deploy/kubero/compose.yaml`](../../deploy/kubero/compose.yaml)
- [`deploy/kubero/README.md`](../../deploy/kubero/README.md)
- [`deploy/kubero/smoke.mjs`](../../deploy/kubero/smoke.mjs)
- [`deploy/kubero/.env.example`](../../deploy/kubero/.env.example)
- [`deploy/kubero/nginx.conf.template`](../../deploy/kubero/nginx.conf.template)
- [`backend/package.json`](../../backend/package.json)
- [`web/package.json`](../../web/package.json)
- [Workflow PR tests](../../.github/workflows/pr-tests.yml)
- [Workflow Kubero images](../../.github/workflows/kubero-images.yml)
- [Issue #451](https://github.com/cchelooo/ApuntesUCT/issues/451)
- [Run `PR tests` #506](https://github.com/cchelooo/ApuntesUCT/actions/runs/43619110816)
- [Run `Kubero images` para `93a0018`](https://github.com/cchelooo/ApuntesUCT/actions/runs/43740083104)
