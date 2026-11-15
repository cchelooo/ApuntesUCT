# Línea base de integración y prerrequisitos de Kubero — Sprint 3

**Issue:** [#451 — Establecer línea base de integración y prerrequisitos de Kubero](https://github.com/cchelooo/ApuntesUCT/issues/451)
**Plan:** S3-11 · **Hito:** Infraestructura
**Fecha de revisión:** 15 de noviembre de 2026
**Commit de `main` validado por CI y publicado en GHCR:** [`93a00181f7318cda4dee63581f44f482d0dfff08`](https://github.com/cchelooo/ApuntesUCT/commit/93a00181f7318cda4dee63581f44f482d0dfff08)

## Alcance y conclusión ejecutiva

Esta revisión inspecciona el repositorio y las ejecuciones de GitHub Actions. No se
crearon recursos ni se realizaron cambios de arquitectura. No se proporcionó una
URL ni acceso al panel del Kubero existente; por tanto, no es posible confirmar
qué aplicaciones, réplicas o tags están corriendo allí ni ejecutar solicitudes
HTTP contra ese entorno. **Una imagen publicada o un smoke test efímero de CI no
equivale a un despliegue verificado en Kubero.**

El commit indicado construyó la pila Compose aislada, pasó el smoke test y publicó
imágenes inmutables por SHA y `latest` en GHCR. Auth ya implementa registro/login
con JWT firmado RS256; la comprobación de CI no demuestra todavía la autorización
de esas solicitudes en todas las rutas de dominio. Quality ya tiene workspace,
bootstrap y contrato de salud en el código, pero sigue fuera del Compose de
Kubero y del conjunto de imágenes publicadas. Web se construye como SPA React/Vite
servida por Nginx y reenvía `/api/` al Gateway; su dominio/TLS y comportamiento
en el Kubero compartido no pudieron comprobarse.

## 1. Aplicaciones, versiones, tags y dependencias

La versión es la declarada en el `package.json`; no representa necesariamente una
versión desplegada. El workflow de imágenes publica artefactos para el commit
`93a0018` con el tag inmutable `sha-93a00181f7318cda4dee63581f44f482d0dfff08`
y el tag mutable `latest`. El run de publicación concluyó correctamente. No hay
evidencia de que Kubero esté configurado para consumir dichos tags.

| App / rol operativo | Versión y tecnología declaradas | Imagen y tag publicados para el commit validado | Puerto y dependencias principales | Estado real en Kubero |
| --- | --- | --- | --- | --- |
| `client` (`web`) | `web@0.0.0`; SPA React `^19.2.8`, Vite `^8.2.2`; Nginx sirve los artefactos estáticos. | `ghcr.io/cchelooo/apuntesuct-kubero-web:sha-93a00181f7318cda4dee63581f44f482d0dfff08` y `:latest`. | Contenedor `8080`. `GATEWAY_UPSTREAM` dirige Nginx al Gateway por HTTP interno; las llamadas del cliente usan `/api/v1`. | No comprobado. |
| `server` (`api-gateway`) | `api-gateway@0.0.1`; NestJS `11.2.7`, Node.js `22` en CI. | `ghcr.io/cchelooo/apuntesuct-kubero-api-gateway:sha-93a00181f7318cda4dee63581f44f482d0dfff08` y `:latest`. | Contenedor `3000`. Enruta solicitudes HTTP internas a Auth, Catalog, Material y Search; no declara una base propia en el Compose Kubero. | No comprobado. |
| `auth-service` | `auth-service@0.0.1`; NestJS `11.2.7`, Prisma `6.12.0`. El flujo de registro/login emite JWT RS256. | `ghcr.io/cchelooo/apuntesuct-kubero-auth-service:sha-93a00181f7318cda4dee63581f44f482d0dfff08` y `:latest`. | Contenedor `3001`; PostgreSQL dedicado (`auth_db`). Gateway consume su API. La clave privada se monta como secret, no se incorpora a la imagen. | No comprobado. |
| `catalog-service` | `catalog-service@0.0.1`; NestJS `11.2.7`, Prisma `6.12.0`. | `ghcr.io/cchelooo/apuntesuct-kubero-catalog-service:sha-93a00181f7318cda4dee63581f44f482d0dfff08` y `:latest`. | Contenedor `3002`; PostgreSQL dedicado (`catalog_db`). Es consultado por Gateway, Material y Search. | No comprobado. |
| `material-service` | `material-service@0.0.1`; NestJS `11.2.7`, Prisma `6.12.0`. | `ghcr.io/cchelooo/apuntesuct-kubero-material-service:sha-93a00181f7318cda4dee63581f44f482d0dfff08` y `:latest`. | Contenedor `3003`; PostgreSQL dedicado (`material_db`), Catalog por HTTP y MinIO para objetos/binarios. | No comprobado. |
| `search-service` | `search-service@0.0.1`; NestJS `11.2.7`. | `ghcr.io/cchelooo/apuntesuct-kubero-search-service:sha-93a00181f7318cda4dee63581f44f482d0dfff08` y `:latest`. | Contenedor `3005`; consulta Catalog y Material por HTTP. No usa una base propia en el Compose Kubero revisado. | No comprobado. |
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
| Web (`client`) | `GET /health`; el smoke lo solicita con expectativa explícita `200`. | **200** en el Compose efímero. | Texto plano `ok` (Nginx). No valida API ni dependencias. |
| Gateway (`server`) | `GET /health` y `GET /api/v1/health`; el smoke espera `200` en ambos. | **200** en el Compose efímero. | JSON `{ "status": "ok", "service": "API Gateway", "timestamp": "<ISO-8601>" }`. Es una comprobación de disponibilidad del proceso, no de sus upstreams. |
| Auth | `GET /api/v1/health`; healthcheck de Compose exitoso. El smoke también obtuvo el status esperado `200` del proxy `/api/v1/auth/health`. | **2xx** para el endpoint directo según healthcheck (este no registra el status exacto); **200** para el endpoint probado por Gateway/Web. | `{ "status": "ok", "service": "auth-service", "database": "connected", "timestamp": "<ISO-8601>" }`; si PostgreSQL no está disponible, el servicio responde `503` con estado `unavailable`/`disconnected`. |
| Catalog | `GET /health`; healthcheck de Compose exitoso. | **2xx**; el healthcheck solo comprueba `response.ok`, no conserva el status exacto. | `{ "status": "ok", "service": "catalog-service", "timestamp": "<ISO-8601>" }`. Es un chequeo del servicio, no de PostgreSQL. |
| Material | `GET /api/v1/health`; healthcheck de Compose exitoso. | **2xx**; el healthcheck solo comprueba `response.ok`. | `{ "status": "ok", "service": "material-service", "timestamp": "<ISO-8601>" }`. No acredita por sí solo Catalog, MinIO ni autorización. |
| Search | `GET /api/v1/health`; healthcheck de Compose exitoso. | **2xx**; el healthcheck solo comprueba `response.ok`. | Terminus: `{ "status": "ok", "info": {}, "error": {}, "details": {} }` cuando no registra checks fallidos. |
| Quality | Hay controlador de salud `/health` en el código; no existe servicio Quality en el Compose de Kubero ni en el smoke de imágenes. | **Sin solicitud y sin código HTTP verificado.** | El código define `status`, `service` y `database`; no se debe registrar como endpoint disponible ni saludable hasta desplegarlo y probarlo. |

Los healthchecks backend de Compose prueban HTTP y éxito 2xx; no todos son
chequeos profundos de dependencias. MinIO tiene una comprobación de vida
`/minio/health/live` en el smoke, pero la respuesta no se registra como una
medición del Kubero existente. Para cerrar la comprobación operativa se requiere
la URL/base de cada app en el entorno actual, la fecha y hora UTC, el status y
payload saneado observados directamente, además de correlacionar el tag real de
cada app.

## 3. Variables de entorno y comunicación entre servicios

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

### Estado observado

| Evidencia | Resultado | Alcance / limitación |
| --- | --- | --- |
| [PR tests del PR #506, run `43619110816`](https://github.com/cchelooo/ApuntesUCT/actions/runs/43619110816), 14-11-2026 | Todos los 12 checks listados concluyeron `success`: backend, E2E de Gateway/Auth/Catalog/Material, integración Material, regresión browser Web/Gateway, lint/formato Web, pruebas Web unitarias/integración y Mobile. | Corresponde a los checks previos al merge del cambio Auth que precede al SHA integrado; es evidencia de la revisión del código, no una prueba ejecutada por `PR tests` sobre el commit de merge. |
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
levanta el Compose aislado, espera healthchecks, ejecuta el smoke y, solo en push
a `main`, etiqueta y publica siete imágenes en GHCR. La lista publicada incluye
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
| Alta | No hay evidencia observable del inventario real de apps, imágenes, réplicas, variables, rutas, DNS, dominio/TLS ni salud HTTP en Kubero. El entorno no fue accesible desde esta revisión. | Obtener acceso/URLs del Kubero existente; registrar para cada app tag/digest activo, puerto, fecha UTC, status y payload saneado del endpoint. Confirmar dependencias en la red real antes de declarar integración. |
| Alta | Auth ya emite JWT RS256 y el smoke valida firma, issuer/audience, identidad, rol y expiración. Sin embargo, la documentación de despliegue indica que la validación JWT de rutas protegidas de dominio sigue pendiente; salud/login exitosos no equivalen a autorización integrada. | Enlazar validadores en Gateway/servicios según el contrato vigente; comprobar token ausente, inválido, expirado y rol insuficiente con tests E2E; completar Web → Gateway → Auth → Material. Mantener claves fuera de repositorio, cliente y logs, y documentar rotación. |
| Alta | Quality existe como workspace y tiene implementación/contrato de salud, pero no se empaqueta ni ejecuta en el despliegue Kubero: falta imagen, servicio Compose, variables operativas, healthcheck de contenedor y wiring/ruta Gateway. La base Quality no está declarada en el Compose Kubero. | Acordar contrato API, consumidores, autorización, necesidad/esquema de persistencia y ownership. Después añadir Quality al pipeline y al entorno existente con configuración, migraciones, healthcheck, smoke, pruebas E2E e instrucciones de rollback. No crear un entorno paralelo. |
| Alta | Los tags publicados `sha-93a0018…` y `latest` acreditan publicación, no que Kubero los haya promovido. `latest` además es mutable. | Inspeccionar el tag/digest configurado en cada app y desplegar/promover explícitamente en Kubero con un tag inmutable, ventana de verificación y tag previo de rollback. |
| Media | Web se construye y pasa la regresión automatizada, pero dominio/TLS, upstream y comportamiento autenticado en el Kubero existente no se comprobaron. | Confirmar dominio, TLS, rutas y `GATEWAY_UPSTREAM`; validar sesión, expiración, logout, respuestas `401` y errores reales contra el Gateway desplegado, sin datos/secretos en el bundle. |
| Alta | El Compose raíz versiona credenciales de DB en texto plano y no debe confundirse con la topología Kubero. | Externalizar los valores y rotar los que hayan sido reutilizados, sin propagarlos a logs, imágenes, documentación ni variables del cliente. |
| Media | No hay job E2E dedicado para Quality ni Search en la matriz PR; la cobertura de salud/funcionalidad de esos servicios depende del workspace y del smoke de pila, respectivamente. | Añadir suites orientadas a los contratos de Search y Quality antes de declarar integración Sprint 3 completa. |

**Puerta de salida común:** CI verde para el SHA promovido; imagen identificada
por SHA/digest; secretos gestionados fuera del repositorio; comunicación interna
verificada; health HTTP consultado en el Kubero existente con fecha/status; Auth
probado con autorización real; Quality construido e integrado solo tras cerrar
contrato/persistencia; Web comprobada contra el Gateway y dominio/TLS configurados.

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
