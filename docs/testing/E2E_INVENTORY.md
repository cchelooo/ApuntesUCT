# Inventario de E2E e integración existentes

Se revisaron scripts, configuraciones Jest, archivos `*.e2e-spec.ts`,
`*.integration.cjs`, `*.integration.test.tsx` y pruebas live/nativas de Mobile.
No hay configuración Playwright/Cypress ni suite E2E implementada en Search.
Este inventario describe únicamente pruebas preexistentes; no amplía casos ni
sustituye el plan de QA de Semana 4.

## Backend E2E: incluidos en CI

Rutas relativas a `backend/<servicio>/test/`. Todas las suites se ejecutaron
con el script `test:e2e` de su workspace, `--ci --runInBand`, Node.js 22.22.3
y los clientes Prisma generados. No se añadieron exclusiones de archivos/casos.

| Servicio | Archivo | Dependencias |
| --- | --- | --- |
| api-gateway | `app.e2e-spec.ts` | Nest/Supertest y documentación local |
| api-gateway | `auth-proxy.e2e-spec.ts` | Servidor HTTP local y Auth con Prisma simulado |
| api-gateway | `gateway.e2e-spec.ts` | Downstream HTTP simulado en puerto efímero |
| api-gateway | `material-search-proxy.e2e-spec.ts` | Servidores HTTP locales para los upstreams |
| auth-service | `auth.e2e-spec.ts` | PostgreSQL y AppModule real; `DATABASE_URL` explícita evita el fallback local del test |
| auth-service | `login.e2e-spec.ts` | Nest/Supertest, Prisma simulado |
| auth-service | `health.e2e-spec.ts` | Nest/Supertest, Prisma simulado |
| catalog-service | `catalog.e2e-spec.ts` | PostgreSQL migrado; prepara sus propios datos |
| catalog-service | `health.e2e-spec.ts` | PostgreSQL para inicializar AppModule |
| catalog-service | `migration-semester.e2e-spec.ts` | PostgreSQL con permisos DDL; crea y borra su tabla de prueba |
| material-service | `app.e2e-spec.ts` | Nest/Supertest, Prisma simulado |
| material-service | `catalog-http-contract.e2e-spec.ts` | Servidor HTTP de Catalog simulado localmente |
| material-service | `create-material-validation.e2e-spec.ts` | Providers de prueba, sin PostgreSQL real |
| material-service | `create-material-version.e2e-spec.ts` | Caso de uso simulado y HTTP local |
| material-service | `http-exception-filter.e2e-spec.ts` | Filtro real y controlador de prueba |
| material-service | `material-catalog-validation.e2e-spec.ts` | Prisma, almacenamiento y Catalog simulados |
| material-service | `material-detail.e2e-spec.ts` | Prisma simulado |
| material-service | `material-download.e2e-spec.ts` | Prisma y almacenamiento simulados |
| material-service | `material-upload-openapi.e2e-spec.ts` | Swagger y providers de prueba |
| material-service | `material.e2e-spec.ts` | Prisma, almacenamiento, Catalog y autor simulados |

Resultados locales: Gateway **4 suites / 44 pruebas**; Auth **3 / 18**;
Catalog **3 / 21**; Material **10 / 156**. Total: **20 suites / 239 pruebas**,
todas aprobadas. La matriz `Backend E2E (<servicio>)` tiene `fail-fast: false`;
el fallo de un servicio no cancela los otros. Cada instancia tiene PostgreSQL
17 desechable propio y puerto asignado por Docker. Auth y Catalog aplican sus
migraciones antes de probar. Gateway y Material no utilizan esa base.

La configuración de Gateway transforma `httpxy` y módulos JS con ts-jest;
Material conserva `NODE_OPTIONS=--experimental-vm-modules` de su script.
Catalog `test:migration` selecciona un archivo que ya ejecuta `test:e2e`; no se
duplica ese caso. Esto automatiza su prueba existente, no una regresión nueva.

## Backend integración

| Servicio | Archivo | Dependencias y estado |
| --- | --- | --- |
| api-gateway | `material-contract.integration.cjs` | Build de Gateway y Material, clientes Prisma, HTTP local y providers simulados. **Bloqueada**: falla la compilación del módulo Nest por falta de `CatalogPort` en los providers de `CreateMaterial` |
| auth-service | `user-persistence.integration.cjs` | PostgreSQL migrado, `.env` requerido por el script, cliente Prisma. **Bloqueada**: importa `@prisma/client`, pero la configuración genera `.prisma/auth-client`; falla antes de ejecutar los tres casos de persistencia |
| material-service | `persistence.integration.cjs` | PostgreSQL; esquema aleatorio, migraciones, constraints y comparación del esquema |
| material-service | `materials.integration.cjs` | Build de Material, PostgreSQL, servidor HTTP local; esquema aleatorio |
| material-service | `create-material-version.integration.cjs` | Build de Material, PostgreSQL y almacenamiento simulado; requiere `MATERIAL_TEST_DATABASE_URL` |
| material-service | `storage.integration.cjs` | Build de Material y MinIO real; requiere `MATERIAL_TEST_MINIO=1` |
| material-service | `material-version-minio.integration.cjs` | PostgreSQL y MinIO reales; opcionalmente Gateway compilado con `MATERIAL_TEST_GATEWAY=1` |
| material-service | `create-material.integration.cjs` | PostgreSQL, MinIO y Catalog HTTP real/migrado; requiere `MATERIAL_TEST_UPLOAD=1`; crea y elimina referencias de Catalog |

Auth y Gateway se ejecutaron mediante sus scripts `test:integration`: ambos
devolvieron código **1**. No se corrigieron imports, providers, contratos ni
aserciones. Quedan fuera del workflow y de cualquier propuesta de check
obligatorio hasta que sus responsables resuelvan los bloqueos y se repitan
las pruebas. En una instalación limpia Auth también requiere crear un `.env`
de CI, porque su script usa `node --env-file=.env`; no se debe copiar un `.env`
de producción. Generar el cliente oficial no soluciona el import incompatible.

Las **seis suites de Material** pasaron con **23 pruebas, 0 fallos y 0 skips**.
Se incluyen completas en **Material integration** mediante el script oficial
`npm run test:integration --workspace=material-service`. Se habilitaron
`MATERIAL_TEST_MINIO=1`, `MATERIAL_TEST_UPLOAD=1`, `MATERIAL_TEST_GATEWAY=1` y
`MATERIAL_TEST_DATABASE_URL`. El log confirmó el recorrido por Gateway y la
limpieza de buckets/esquemas. `test:storage` ejecuta uno de estos mismos
archivos, por lo que no se duplica.

`.github/scripts/run-material-integration.sh` es infraestructura, no una suite
nueva: crea PostgreSQL 17 y MinIO desechables con puertos locales dinámicos,
aplica las migraciones de Catalog en un esquema propio, inicia Catalog
compilado, espera disponibilidad y llama al script de pruebas. Usa el MinIO
construido con `deploy/kubero/minio.Dockerfile` sin modificarlo (fuente oficial
fijada por commit y checksum). Los tests generan sus datos/buckets/esquemas.
El trap de salida termina Catalog y elimina exclusivamente los contenedores
creados por esa ejecución y sus volúmenes, incluso si fallan las pruebas.
El código de salida original se conserva; `pipefail` impide que `tee` oculte
errores. El comando de pruebas tiene un límite de 300 segundos y el job de
35 minutos, incluyendo la compilación de MinIO.

## Web

`web/src/presentation/pages/CatalogPage.integration.test.tsx` usa jsdom,
Testing Library, React Query y `fetch` simulado. No necesita backend real.
Pasó **1 archivo / 3 pruebas** con el script `test:run` y selección del archivo.
Se ejecuta en **Frontend integration**; **Frontend tests** excluye únicamente
`**/*.integration.test.tsx` para separar esas pruebas, que siguen ejecutándose
en el job de integración. El resto pasó **23 archivos / 149 pruebas**.

No hay pruebas E2E de navegador implementadas. Las pruebas de páginas y
componentes con repositorios simulados siguen en el job de Web existente.

## Mobile: no validadas, fuera de checks de integración

| Archivo | Dependencias y bloqueo |
| --- | --- |
| `mobile/test/integration/gateway_live_test.dart` | Flutter, Gateway, Catalog y Material reales aislados; `RUN_GATEWAY_SMOKE=true`. Permite identificadores de fixtures y escenario de servicios no disponibles |
| `mobile/test/integration/material_upload_live_test.dart` | Flutter y stack real con PostgreSQL/MinIO, contexto de autor, referencias académicas y PDF; `RUN_MATERIAL_UPLOAD_SMOKE=true`, `MATERIAL_TEST_SUBJECT_ID`, `MATERIAL_TEST_CAREER_ID`, `MATERIAL_TEST_PDF_PATH` |
| `mobile/integration_test/material_download_native_test.dart` | Flutter y dispositivo/emulador Android/iOS con plugins y visor PDF; transporte simulado pero guardado/apertura nativos |

No hay Flutter en el entorno local, por lo que no se pueden afirmar resultados
de estas suites ni habilitarlas como checks confiables. Las dos suites live
conservan su opt-in original y aparecen omitidas en `flutter test` sin flags;
no se presentan esos skips como pruebas de integración aprobadas. La suite
nativa necesita también verificar la interacción con el visor del dispositivo.
No se alteraron ni desactivaron tests para ocultar fallos.

## Límites de la verificación

Resultados obtenidos localmente, no en un run de GitHub Actions. No se utilizaron
bases ni servicios existentes de desarrollo/producción. Las pruebas no cubiertas
por suites preexistentes, la ampliación de escenarios y las regresiones completas
de Semana 4 siguen pendientes. La aprobación local de estas suites no equivale
a completar esas tareas de QA.
