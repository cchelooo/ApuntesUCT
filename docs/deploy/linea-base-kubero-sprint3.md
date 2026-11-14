# Línea base de integración y prerrequisitos de Kubero — Sprint 3

**Issue:** [#451 — Establecer línea base de integración y prerrequisitos de Kubero](https://github.com/cchelooo/ApuntesUCT/issues/451)
**Plan:** S3-11 · **Hito:** Infraestructura · **Corte de revisión:** 9 de noviembre de 2026
**Fuente de configuración:** rama `main`, commit `317d3477259aa6fc059eeebb11093f951b5d3768`.

## Resumen ejecutivo

El repositorio ya contiene un despliegue reproducible para Kubero en
[`deploy/kubero/compose.yaml`](../../deploy/kubero/compose.yaml), imágenes para
Web, Gateway, Auth, Catalog, Material, Search y MinIO, healthchecks de contenedor,
una prueba de humo y workflows de CI. Esta evidencia acredita que la pila puede
construirse y probarse en CI; **no acredita por sí sola que las aplicaciones estén
desplegadas ni saludables en el Kubero compartido**.

La principal brecha funcional es Auth: en el corte revisado mantiene el flujo
mock y emite JWT sin firma; Material no permite crear contenido en producción
hasta integrar autenticación real. Quality tiene código organizado por capas,
pero no es un servicio ejecutable: no figura como workspace npm ni como servicio
de Compose y no se construye una imagen. Web está incluida en la pila y es servida
por Nginx, pero requiere validación contra el backend desplegado y configuración
de dominio/TLS del entorno existente.

No se encontró una URL del entorno Kubero ni acceso a sus aplicaciones para
realizar solicitudes en vivo. Por ello, las rutas de salud se verificaron contra
la configuración/código y contra la ejecución efímera del workflow de imágenes;
el estado de salud actual del despliegue Kubero queda **pendiente de comprobación
operativa**.

## 1. Componentes, disponibilidad y dependencias

“Incluido en Compose” describe lo definido en el repositorio. El estado real en
Kubero debe confirmarse en el panel o mediante las URLs del entorno.

| Componente | Línea base del repositorio | Puerto interno y salud configurada | Dependencias principales |
| --- | --- | --- | --- |
| Web | Imagen y contenedor incluidos; Nginx sirve la SPA y enruta `/api/` al Gateway. Presencia real en Kubero: no comprobada. | `8080`, `/health` | Gateway mediante `GATEWAY_UPSTREAM`. |
| API Gateway | Servicio Nest incluido y expuesto localmente solo en loopback por Compose. Presencia real en Kubero: no comprobada. | `3000`, `/health` | Auth, Catalog, Material y Search por URLs internas. |
| Auth | Servicio Nest, imagen y migraciones incluidos. Presencia real en Kubero: no comprobada. La autenticación funcional sigue siendo mock en el corte revisado. | `3001`, `/api/v1/health` | PostgreSQL `auth_db`. |
| Catalog | Servicio Nest, imagen y migraciones incluidos. Presencia real en Kubero: no comprobada. | `3002`, `/health` | PostgreSQL `catalog_db`. |
| Material | Servicio Nest, imagen y migraciones incluidos. Presencia real en Kubero: no comprobada. La escritura protegida aún depende de Auth real. | `3003`, `/api/v1/health` | PostgreSQL `material_db`, Catalog y MinIO/bucket `materials`. |
| Search | Servicio Nest e imagen incluidos. Consulta Catalog y Material por HTTP; no necesita una base propia en el Compose de Kubero. Presencia real en Kubero: no comprobada. | `3005`, `/api/v1/health` | Catalog y Material. |
| Quality | Hay estructura de código bajo `backend/quality-service/src`, pero no hay paquete npm, entrada ejecutable, workspace, imagen, app Compose ni endpoint de salud desplegable. **Pendiente como servicio.** | No definido | Debe concretar persistencia e integración antes de añadirlo al despliegue. |

### Persistencia y relaciones

| Recurso | Definido en `deploy/kubero/compose.yaml` | Uso y relación |
| --- | --- | --- |
| PostgreSQL `db-auth` | Sí | Base exclusiva de Auth (`auth_db`). |
| PostgreSQL `db-catalog` | Sí | Base exclusiva de Catalog (`catalog_db`). |
| PostgreSQL `db-material` | Sí | Base exclusiva de Material (`material_db`). |
| PostgreSQL para Search | No | Search obtiene datos desde Catalog y Material por HTTP. |
| PostgreSQL para Quality | No | El Compose raíz `docker-compose.yml` sí declara una base Quality local, pero no hay servicio Quality asociado ni esa base aparece en el Compose Kubero. No asumir que está desplegada. |
| MinIO | Sí | Almacenamiento de objetos privado; `minio-init` crea el bucket `materials` y Material consume MinIO. |

El Compose de Kubero condiciona Auth, Catalog y Material a que sus bases estén
saludables; Material espera además Catalog y la inicialización de MinIO. Search
espera Catalog y Material. Gateway espera los cuatro servicios. Web espera Gateway.
La salud HTTP de los servicios backend es comprobada por un healthcheck común;
PostgreSQL usa `pg_isready`. MinIO no tiene un healthcheck Docker explícito en
este Compose: la prueba de humo consulta su endpoint de vida y la inicialización
del bucket aplica reintentos.

El `docker-compose.yml` de la raíz es un entorno local separado: define además
bases para Search y Quality y usa credenciales de base de datos literales en el
archivo. No debe tratarse como inventario de recursos de Kubero. Sustituir esas
credenciales por secretos y rotarlas si fueron reutilizadas fuera de un entorno
local.

## 2. Salud, rutas y comunicación

### Rutas encontradas

| Servicio | Ruta configurada | Qué acredita la evidencia |
| --- | --- | --- |
| Web | `GET /health` | Nginx devuelve `200` con `ok`; existe healthcheck de contenedor. |
| Gateway | `GET /health` | Ruta usada por el healthcheck y documentada para la app. No es `/api/v1/health` en esta configuración. |
| Auth | `GET /api/v1/health` | Ruta indicada por Compose y healthcheck backend. |
| Catalog | `GET /health` | Ruta indicada por Compose y healthcheck backend. |
| Material | `GET /api/v1/health` | Ruta indicada por Compose y healthcheck backend. |
| Search | `GET /api/v1/health` | Ruta indicada por Compose y healthcheck backend. |
| MinIO | `GET /minio/health/live` | Ruta usada como comprobación del servicio en la documentación/pruebas. |
| Quality | No disponible | No hay runtime ni ruta declarada. |

Nginx escucha en el puerto de contenedor `8080`, atiende `/health` localmente y
reenvía las peticiones `/api/` al upstream definido por `GATEWAY_UPSTREAM`,
preservando el path. Compose asigna `http://gateway:3000` como upstream dentro
de su red.

### Alcance de la comprobación

- **Configuración/código:** las rutas y los puertos anteriores aparecen en
  `deploy/kubero/compose.yaml`, `deploy/kubero/README.md` y
  `deploy/kubero/nginx.conf.template`.
- **Integración efímera:** el workflow
  [`Kubero images`](../../.github/workflows/kubero-images.yml) construye y
  levanta la pila, y ejecuta `deploy/kubero/smoke.mjs`. La ejecución exitosa más
  reciente consultada fue el run
  [42739726165](https://github.com/cchelooo/ApuntesUCT/actions/runs/42739726165),
  en el PR #501. Esto demuestra éxito de build y smoke test en ese run, no
  disponibilidad continua ni estado del Kubero compartido.
- **Entorno vivo:** no comprobado: la sesión no tenía URL pública/interna del
  despliegue ni acceso al panel. Antes de declarar la línea base operativa,
  registrar fecha, URL no secreta, respuesta HTTP de cada endpoint y revisión
  de la app correspondiente en Kubero.

`smoke.mjs` incluye verificaciones de Web/Gateway, rutas de lectura del API y
descarga/consulta con datos fixture temporales. No demuestra el flujo de alta
autenticada ni una carga real de material por un usuario.

## 3. Variables y tratamiento de secretos

| Variable / configuración | Uso | Requisito para Sprint 3 |
| --- | --- | --- |
| `WEB_PORT` | Puerto del host para Web; por defecto `18080`, enlazado a `127.0.0.1`. Solo corresponde al Compose local. | En Kubero configurar el puerto de contenedor de Web (`8080`) y el dominio/ruta en la app; no trasladar el puerto local como puerto interno. |
| `GATEWAY_PORT` | Puerto del host para Gateway; por defecto `13000`, enlazado a `127.0.0.1`. Solo corresponde al Compose local y a pruebas locales. | Mantener Gateway como upstream interno en Kubero; publicar solo lo que requiera la arquitectura/ruta existente. |
| `PORT` | Puerto interno de cada proceso Nest (`3000`, `3001`, `3002`, `3003`, `3005`). | Mantenerlo coherente con el puerto configurado en la app Kubero y su healthcheck. |
| `HEALTH_PATH` | Ruta usada por el healthcheck común de Compose para backend. | Configurar la ruta específica de cada servicio; no asumir que todos usan el prefijo `/api/v1`. |
| `AUTH_SERVICE_URL`, `CATALOG_SERVICE_URL`, `MATERIAL_SERVICE_URL`, `SEARCH_SERVICE_URL` | Direcciones de comunicación Gateway → microservicios. | Usar DNS/nombre de apps y puertos internos de la red Kubero existente, no `localhost` entre contenedores. |
| `CATALOG_SERVICE_URL`, `MATERIAL_SERVICE_URL` | Direcciones de Search → Catalog/Material; Material también usa Catalog. | Probar resolución DNS y conectividad entre apps. |
| `GATEWAY_UPSTREAM` | Upstream Nginx → Gateway; localmente apunta a `gateway:3000`. | Actualizarlo al nombre de servicio interno que corresponda en Kubero. |
| `DATABASE_URL` | Conexión Prisma de Auth, Catalog y Material. | Definir cada URL en la app correspondiente, con host interno, DB correcta y contraseña codificada para URL si incluye caracteres reservados. Guardarla como secreto. |
| `POSTGRES_PASSWORD` | Contraseña exigida por Compose para las bases del stack aislado. | Usar un secreto aleatorio gestionado por el entorno; no reutilizar el valor de ejemplo. |
| `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD` | Credenciales administrativas del MinIO local. | No usar el usuario root de MinIO como credencial normal de Material en producción. Gestionar un usuario/política de mínimo privilegio y guardar sus claves como secretos. |
| `MINIO_ENDPOINT`, `MINIO_PORT`, `MINIO_USE_SSL`, `MINIO_BUCKET`, `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY` | Conexión Material → MinIO. | Confirmar endpoint interno, TLS, bucket y credenciales de servicio en Kubero. Mantener el bucket privado. |
| `VITE_API_URL` | Base API de la Web en desarrollo/Vite. | Comprobar qué valor se incorpora en la compilación de producción y asegurar que la Web desplegada use la ruta pública correcta, preferiblemente a través del proxy `/api/`. No incluir secretos en variables `VITE_*`. |

`deploy/kubero/.env.example` contiene valores de muestra explícitamente limitados
a Compose local; son públicos y no son secretos. Las credenciales productivas
deben configurarse como secretos de Kubero, nunca copiarse al documento, a la
imagen o a logs. El Compose raíz contiene credenciales literales y debe
considerarse una incidencia de higiene de secretos, incluso si actualmente se
usa solo en desarrollo.

## 4. Pruebas automatizadas y CI/CD

### Cobertura configurada

El workflow [`PR tests`](../../.github/workflows/pr-tests.yml) se activa en PR
hacia `main` (y manualmente) y define:

- Backend: `npm ci` y `npm run test:ci -- --coverage`. La matriz E2E incluye
  Gateway, Auth, Catalog y Material con PostgreSQL desechable; el workflow
  ejecuta migraciones E2E para Auth y Catalog. Search no está en esa matriz.
- Material tiene además un job de integración con servicios desechables y
  MinIO. Quality no está cubierto por Jest/workspaces porque todavía no es un
  paquete ejecutable.
- Web: Vitest con cobertura; la suite unitaria excluye los archivos de
  integración, que tienen un job frontend de integración separado.
- Mobile: `flutter test --coverage`. El workflow no ejecuta `integration_test`
  de Flutter como prueba de dispositivo end-to-end.
- `PR tests` no define un job explícito de lint; el build de imágenes valida la
  compilación de las imágenes, pero no sustituye un chequeo dedicado de lint.

El workflow [`Kubero images`](../../.github/workflows/kubero-images.yml) compila
la pila con Docker Compose, espera salud, ejecuta el smoke test y adjunta logs
si falla. Solo publica imágenes en GHCR al hacer push a `main`; el PR no publica
imágenes. Las ejecuciones observadas para el PR #501:

| Workflow | Run | Resultado observado |
| --- | --- | --- |
| PR tests | [42739725966](https://github.com/cchelooo/ApuntesUCT/actions/runs/42739725966) | Éxito. |
| Kubero images | [42739726165](https://github.com/cchelooo/ApuntesUCT/actions/runs/42739726165) | Éxito; build/arranque y smoke test completados. |

En el historial inmediato también hubo ejecuciones fallidas anteriores en la
rama del mismo PR, seguidas por runs exitosos. La referencia de estado de esta
línea base es el run verde más reciente consultado, no una garantía de que otros
commits o la rama `main` tengan idéntico resultado. El job de publicación se
omite en PR.

### Ejecución local recomendada

Desde la raíz del repositorio, con Docker Compose v2 y Node.js 22, la guía del
despliegue documenta:

```bash
docker compose --env-file deploy/kubero/.env \
  -f deploy/kubero/compose.yaml up --build --wait --wait-timeout 180
node deploy/kubero/smoke.mjs
```

Crear `deploy/kubero/.env` a partir del ejemplo y reemplazar los valores de
muestra por valores locales propios antes del primer comando. No trasladar esos
valores a Kubero ni al repositorio.

## 5. Prerrequisitos de integración para Sprint 3

### Auth

1. Sustituir el login mock por validación real de identidad/credenciales y emitir
   tokens firmados con clave gestionada como secreto; documentar expiración,
   issuer/audience y rotación. No aceptar JWT sin firma.
2. Confirmar que rutas, contrato de login/registro y claims coinciden entre Auth,
   Gateway, Material y Web. Mantener la validación de autorización en el
   servidor; una bandera de UI no debe conceder permisos.
3. Configurar `DATABASE_URL` de Auth y migraciones en la app Kubero existente;
   verificar el endpoint de salud, manejo seguro de errores y logs sin tokens ni
   datos de credenciales.
4. Añadir/actualizar pruebas unitarias, E2E e integración que cubran login
   válido/inválido, autorización y el flujo Web → Gateway → Auth → Material.
5. Mantener desactivado el autor temporal de Material en producción; el propio
   despliegue ya lo define como desactivado.

### Quality

1. Completar `backend/quality-service` como servicio ejecutable: `package.json`,
   scripts, configuración Nest/TypeScript, módulo bootstrap, controladores,
   validación de configuración y pruebas.
2. Decidir qué entidad persiste Quality y su esquema/propiedad de datos. El
   Compose Kubero actual no declara base Quality; si hace falta persistencia,
   planificarla como extensión del entorno existente, no como una infraestructura
   paralela. Definir migraciones y restauración antes del despliegue.
3. Acordar contrato API, dependencias entrantes/salientes, puerto y ruta de
   salud; incorporar de forma explícita el nuevo workspace a scripts,
   Dockerfile/build y estrategia de despliegue.
4. Añadir pruebas unitarias, E2E con dependencias desechables, smoke test y
   healthcheck. Añadir el servicio a Gateway únicamente cuando su contrato y
   autorización estén definidos.
5. Publicar y desplegar la imagen en la app del entorno Kubero existente una vez
   aprobados build, pruebas y revisión de secretos.

### Web

1. Confirmar en la imagen de producción el origen/base API compilado por Vite y
   su correspondencia con el proxy Nginx `/api/` → Gateway.
2. Configurar en Kubero el dominio y TLS sobre la app Web existente; preservar
   el upstream interno del Gateway y las cabeceras proxy necesarias.
3. Integrar autenticación de forma segura: no almacenar ni exponer claves
   privadas en el cliente, aplicar expiración/cierre de sesión y manejar `401`
   y errores de API de forma consistente.
4. Agregar una prueba browser/integración del flujo Web autenticado y las
   capacidades de Quality; ejecutar también las pruebas móviles pertinentes si
   la app Mobile consume los mismos cambios.
5. Promover únicamente imágenes producidas por el workflow verde y redesplegar
   explícitamente en Kubero. La publicación GHCR no actualiza automáticamente
   las apps desplegadas.

## 6. Problemas y acciones correctivas

| Prioridad | Hallazgo | Acción recomendada / condición de salida |
| --- | --- | --- |
| Alta | No hay evidencia desde esta revisión del estado de las apps en Kubero ni respuesta en vivo de sus healthchecks. | Obtener del equipo de plataforma URLs/nombres de apps del entorno ya existente; consultar todas las rutas de salud, revisar configuración de puertos y DNS interno y registrar timestamp/resultado. No declarar “desplegado” solo por la presencia de Compose o por CI. |
| Alta | Auth aún mock y JWT sin firma según la documentación del corte; Material productivo rechaza escrituras sin Auth real. | Completar auth segura, validar contrato extremo a extremo y conservar deshabilitado el bypass de desarrollo. Puerta de salida: pruebas positivas y negativas más smoke autenticado. |
| Alta | Quality no se ejecuta ni puede integrarse en Kubero actualmente. | Implementar paquete/servicio y contrato, resolver persistencia, healthcheck, pruebas e imagen; reutilizar el entorno existente. |
| Alta | `docker-compose.yml` raíz contiene credenciales de base de datos literales y difiere de la topología Kubero. | Eliminar credenciales del archivo mediante el cambio técnico correspondiente, usar secretos locales y rotar cualquier valor que haya sido reutilizado. No copiar los valores al reporte. |
| Media | La topología Kubero no incluye DB de Search ni Quality, mientras el Compose raíz sí las declara. | Mantener Search sin DB propia si el diseño sigue siendo HTTP→Catalog/Material. Crear persistencia de Quality solo tras confirmar necesidad/esquema y planificar su adición al entorno existente. |
| Media | No hay prueba en el workflow PR de integración de Flutter en dispositivo; el test configurado es `flutter test`. | Añadir job de integración Flutter cuando haya runner/emulador y casos que dependan de plataforma; registrar esa limitación para cambios transversales Web/Mobile. |
| Media | El smoke de infraestructura valida lectura/descarga y datos temporales, no alta autenticada/subida funcional. | Agregar escenario end-to-end con identidad real y limpieza del fixture después de integrar Auth; no interpretar el smoke actual como aceptación funcional completa. |
| Media | `WEB_PORT`/`GATEWAY_PORT` son puertos host del Compose local, no puertos de escucha del contenedor ni configuración de service discovery Kubero. | En Kubero usar los puertos internos declarados por cada aplicación y DNS interno; mantener el Gateway público solo si lo exige el consumidor Mobile. |

## 7. Secuencia y puertas de salida sugeridas

1. **Verificar entorno actual (antes de desplegar cambios):** inventariar apps,
   imágenes/tag, dominio/TLS, variables secretas, volúmenes y rutas de red del
   Kubero existente. Ejecutar healthchecks HTTP en vivo y capturar resultados
   saneados.
2. **Integrar Auth:** reemplazar mocks, conectar migraciones/secreto de firma,
   enlazar Gateway/Material y Web, aprobar pruebas de autorización y flujo
   autenticado.
3. **Habilitar Quality:** cerrar diseño de API y persistencia, completar build,
   pruebas, imagen y healthcheck. Añadir solo los recursos necesarios al entorno
   actual con migración/rollback explícitos.
4. **Integrar Web:** fijar origen API, dominio/TLS y comportamiento de sesión;
   aprobar pruebas browser contra el Gateway y las funcionalidades del Sprint 3.
5. **Promover a Kubero:** usar tag inmutable generado por CI, actualizar las
   apps existentes de forma ordenada, verificar salud/rutas y conservar tag
   anterior para rollback. No crear un segundo clúster/entorno.

**Puerta común de aceptación:** workflow PR verde, build+smoke verde, salud
confirmada en vivo por app, dependencias internas resueltas, secretos gestionados
fuera del repositorio y evidencia funcional autenticada donde aplique.

## 8. Matriz de criterios de aceptación de la Issue #451

| Criterio | Resultado de esta línea base |
| --- | --- |
| Estado de servicios y componentes de Kubero documentado | Configuración y artefactos documentados; el estado real de despliegue queda pendiente de inspección en el entorno. |
| Disponibles, pendientes y dependencias identificados | Sí: matriz de componentes y persistencia; “incluido en Compose” está separado de “activo en Kubero”. |
| Endpoints de salud comprobados | Rutas verificadas en la configuración y smoke de CI. La comprobación HTTP en el Kubero compartido queda pendiente por falta de URL/acceso a la sesión. |
| Variables revisadas sin revelar secretos | Sí; se documentan nombres, función y tratamiento, sin valores de credenciales. |
| Pruebas y workflows revisados | Sí; se describen suites/workflows y los runs recientes consultados. |
| Prerrequisitos para Auth, Quality y Web | Sí; definidos arriba con puertas de salida. |
| Problemas y acciones correctivas registrados | Sí; matriz priorizada en la sección 6. |
| Diagnóstico que permita continuar sobre la infraestructura existente | Sí; secuencia y criterios de promoción definidos sin proponer una infraestructura paralela. |

## Referencias del repositorio

- [`deploy/kubero/compose.yaml`](../../deploy/kubero/compose.yaml)
- [`deploy/kubero/README.md`](../../deploy/kubero/README.md)
- [`deploy/kubero/nginx.conf.template`](../../deploy/kubero/nginx.conf.template) y [`deploy/kubero/nginx-main.conf`](../../deploy/kubero/nginx-main.conf)
- [`deploy/kubero/smoke.mjs`](../../deploy/kubero/smoke.mjs)
- [`deploy/kubero/.env.example`](../../deploy/kubero/.env.example) y [`.env.example`](../../.env.example)
- [`docker-compose.yml`](../../docker-compose.yml)
- [`backend/package.json`](../../backend/package.json)
- [`web/package.json`](../../web/package.json) y [`web/.env.example`](../../web/.env.example)
- [`mobile/pubspec.yaml`](../../mobile/pubspec.yaml)
- [`.github/workflows/pr-tests.yml`](../../.github/workflows/pr-tests.yml)
- [`.github/workflows/kubero-images.yml`](../../.github/workflows/kubero-images.yml)
