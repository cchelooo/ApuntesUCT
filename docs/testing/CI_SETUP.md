# CI de pruebas para Pull Requests

## Activación y alcance

`.github/workflows/pr-tests.yml` ejecuta **PR tests** para PR dirigidos a `main`
en los eventos `opened`, `synchronize`, `reopened` y `ready_for_review`, incluidos
los borradores. No filtra por rutas. También permite `workflow_dispatch`;
el botón **Run workflow** estará disponible cuando el workflow esté en la rama
predeterminada. Esta preparación no realiza commits, merges ni cambios en la
protección de ramas.

Los checks **Backend tests**, **Frontend tests**, **Mobile tests**,
**Backend E2E (<servicio>)**, **Frontend integration** y **Material integration**
son jobs independientes, sin `needs`. La matriz E2E usa `fail-fast: false`.
Cada nueva ejecución cancela la anterior del mismo
PR (o de la misma referencia para ejecuciones manuales). Solo se concede
`contents: read`; no se necesitan secretos ni infraestructura de producción.
Los límites son 20 minutos para Backend/Mobile/E2E, 15 para Web e integración
Web, y 35 para Material integration. Los servicios reales son desechables.

Se cachean las descargas de npm usando cada `package-lock.json`, y Flutter/Pub
con Flutter 3.47.2 y `mobile/pubspec.lock`. Cada job instala sus dependencias.
Un fallo de instalación, generación de Prisma o pruebas hace fallar el job.
No hay `continue-on-error`, umbrales mínimos de cobertura ni tolerancia añadida
a pruebas fallidas. La subida de artifacts se intenta incluso si fallan pruebas,
salvo cancelación, sin cambiar el estado fallido del job. Si no se generó un
reporte, la subida avisa de su ausencia.

El workflow existente `.github/workflows/kubero-images.yml` permanece intacto,
con sus propios eventos, smoke checks y publicación.

## Suites incluidas

| Job | Selección y comando | Dependencias externas durante las pruebas |
| --- | --- | --- |
| Backend | `npm run test:ci -- --coverage`: scripts oficiales de los cinco workspaces; Jest selecciona `src/**/*.spec.ts` | Dobles de Prisma, almacenamiento y HTTP; no requiere PostgreSQL ni MinIO |
| Frontend | `npm run test:run -- --coverage --exclude '**/*.integration.test.tsx'`: componentes/páginas existentes | APIs simuladas por las pruebas |
| Backend E2E (matriz) | `npm run test:e2e --workspace=<servicio> -- --ci --runInBand` | PostgreSQL migrado para Auth/Catalog; HTTP local y dobles en Gateway/Material |
| Frontend integration | `npm run test:run -- src/presentation/pages/CatalogPage.integration.test.tsx --coverage` | jsdom y fetch simulado |
| Material integration | `npm run test:integration --workspace=material-service`, invocado por el script de infraestructura | PostgreSQL, MinIO y Catalog desechables; Gateway compilado |
| Mobile | `flutter test --coverage`: pruebas existentes en `mobile/test/` | Repositorios/adaptadores simulados; pruebas live optativas deshabilitadas por defecto |

Backend incluye Gateway (health y proxy), Auth (controladores, DTO y Prisma),
Catalog (servicio y controladores), Search (DTO, filtros, búsqueda, contratos y
adaptadores HTTP) y Material (creación, versiones, autor, almacenamiento, DTO y
controladores). El script raíz genera los clientes Prisma de Auth, Catalog y
Material antes de ejecutar las pruebas; no ejecuta migraciones.

Search ya tiene ocho suites. Su script oficial conserva `--passWithNoTests`:
solo tolera la ausencia de pruebas, no errores en las existentes. No se modificó.

Web reparte sus 24 archivos existentes entre 23 del job principal y
`CatalogPage.integration.test.tsx` del job de integración, que usa `fetch`
simulado: ejecutar esta suite existente no constituye la regresión
completa de integración Web planificada para Semana 4.

Mobile incluye pruebas de dominio, datos, providers, widgets, navegación,
autenticación, catálogo y materiales. `mobile/README.md` registra Flutter 3.47.2
con Dart 3.13.2, compatible con `environment.sdk: ^3.13.2` del pubspec.

## Suites fuera de este workflow

El [inventario completo](E2E_INVENTORY.md) enumera cada archivo E2E/integración,
sus dependencias, comandos y resultados.

- **Auth integration:** falla porque importa `@prisma/client`, mientras el
  generador oficial produce `.prisma/auth-client`. Su script también exige `.env`.
- **Gateway integration:** falla al compilar su módulo de pruebas: falta el
  provider `CatalogPort` requerido por `CreateMaterial`.
- **Mobile live y nativa:** no verificadas por falta de Flutter local;
  necesitan stack/fixtures aislados o dispositivo/emulador con plugins y visor.
  Los skips originales de las suites live no cuentan como integración aprobada.
- **Search E2E:** su script solo imprime un mensaje; no hay suite implementada.

Auth y Gateway integration devolvieron código 1; se mantienen fuera de checks
obligatorios, sin modificar sus pruebas ni lógica de negocio. Los nuevos casos
y las regresiones completas de Semana 4 siguen pendientes. El E2E de migración
existente de Catalog sí se ejecuta dentro de su script `test:e2e`.

## Reproducción local

Desde la raíz del repositorio, con Node.js 22 y npm:

```bash
cd backend
npm ci
npm run test:ci -- --coverage
```

En otra terminal, desde la raíz:

```bash
cd web
npm ci
npm run test:run -- --coverage --exclude '**/*.integration.test.tsx'
npm run test:run -- src/presentation/pages/CatalogPage.integration.test.tsx --coverage
```

Con Flutter 3.47.2 stable disponible en `PATH`, desde la raíz:

```bash
cd mobile
flutter --version
flutter pub get
flutter test --coverage
```

No habilitar los flags live para reproducir el job de Mobile. Las unitarias
no requieren Docker. Los siguientes jobs E2E/integración sí usan servicios
nuevos desechables; no reutilizar bases ni URLs de producción.

Para E2E de Gateway y Material, desde `backend/`:

```bash
npm ci
npm run prisma:generate
npm run test:e2e --workspace=api-gateway -- --ci --runInBand
npm run test:e2e --workspace=material-service -- --ci --runInBand
```

Para Auth/Catalog E2E, desde `backend/`, con Docker disponible (guardar como
script Bash para que el trap limpie los recursos al terminar):

```bash
set -euo pipefail
ci_pg="apuntes-e2e-local-$$"
trap 'docker rm -fv "$ci_pg"' EXIT
docker run -d --name "$ci_pg" -p 127.0.0.1::5432 \
  -e POSTGRES_USER=ci -e POSTGRES_PASSWORD=ci-disposable -e POSTGRES_DB=ci \
  postgres:17-alpine
for attempt in {1..30}; do
  if docker exec "$ci_pg" pg_isready -U ci -d ci; then break; fi
  if [[ "$attempt" -eq 30 ]]; then exit 1; fi
  sleep 2
done
ci_port="$(docker port "$ci_pg" 5432/tcp)"
export DATABASE_URL="postgresql://ci:ci-disposable@127.0.0.1:${ci_port##*:}/ci?schema=auth"
npm run prisma:generate
npm run prisma:deploy --workspace=auth-service
npm run test:e2e --workspace=auth-service -- --ci --runInBand
export DATABASE_URL="${DATABASE_URL%auth}catalog"
npm run prisma:deploy --workspace=catalog-service
npm run test:e2e --workspace=catalog-service -- --ci --runInBand
```

Para **Material integration**, desde la raíz, con Node 22, npm y Docker:

```bash
(cd backend && npm ci && npm run build)
docker build -f deploy/kubero/minio.Dockerfile -t apuntesuct/pr-test-minio:local .
bash .github/scripts/run-material-integration.sh
```

El script levanta y elimina su PostgreSQL, MinIO y Catalog. Habilita todos los
casos optativos de Material ya existentes, incluido Gateway. Escribe los logs
en el directorio temporal anunciado al iniciar. No modifica `.env` del usuario.
La compilación inicial de MinIO puede tardar varios minutos.

## Resultados y cobertura

En el PR, abrir **Checks**, seleccionar el check correspondiente y consultar el
paso de pruebas. También se puede abrir **Actions → PR tests → ejecución**.
Un job rojo bloquea su check aunque otros jobs terminen correctamente.

En el resumen de la ejecución, descargar desde **Artifacts**:

| Artifact | Contenido | Retención |
| --- | --- | --- |
| `backend-coverage` | Directorios por servicio con `lcov.info` e informe HTML de Jest | 14 días |
| `frontend-coverage` | `lcov.info` e informe HTML de Vitest | 14 días |
| `mobile-coverage` | `lcov.info` de Flutter | 14 días |
| `e2e-<servicio>` | Resultados JSON de Jest por servicio | 14 días |
| `frontend-integration-coverage` | LCOV y HTML solo de esa ejecución de integración | 14 días |
| `material-integration-logs` | TAP y logs de PostgreSQL, MinIO y Catalog | 14 días |

Descomprimir y abrir el `index.html` correspondiente para Jest/Vitest. El LCOV
puede leerse con herramientas compatibles; Flutter no genera HTML en este job.
Un run cancelado o un fallo previo a la medición puede no producir artifacts.

Jest ya tenía soporte de cobertura y reporters configurados. Web incorpora
`@vitest/coverage-v8` **5.0.1**, coincidente con Vitest **5.0.1**, y configuración
de cobertura para `src/**/*.{ts,tsx}`, excluyendo declaraciones, setup y entrada
principal. Vitest excluye también los archivos de prueba. Se generan reportes
incluso ante pruebas fallidas. Flutter ofrece `--coverage` sin dependencia extra.
No se comparan estos porcentajes como si midieran el mismo alcance: Jest excluye
además módulos y entrypoints, mientras Flutter mide el código alcanzado por su
instrumentación. No se exige un porcentaje mínimo.

### Validación local de esta preparación

Node.js **22.22.3**, npm **10.9.8**. Instalaciones limpias con `npm ci` y comandos
anteriores de backend/Web terminados con código 0:

| Suite | Archivos/suites | Pruebas aprobadas | Statements | Branches | Functions | Lines |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Gateway | 2 | 21 | 55,10 % | 42,10 % | 50,00 % | 53,19 % |
| Auth | 4 | 35 | 86,66 % | 63,63 % | 66,66 % | 86,27 % |
| Catalog | 3 | 53 | 89,78 % | 79,71 % | 89,36 % | 89,63 % |
| Search | 8 | 121 | 93,95 % | 89,01 % | 94,82 % | 94,63 % |
| Material | 7 | 75 | 65,26 % | 43,28 % | 50,00 % | 66,47 % |
| Web principal | 23 | 149 | 85,57 % | 82,53 % | 83,00 % | 87,48 % |
| Web integración | 1 | 3 | 11,20 % | 9,29 % | 13,50 % | 11,17 % |

Backend: **24 suites y 305 pruebas**. Web: **24 archivos y 152 pruebas**.
Los porcentajes Web ahora corresponden a dos ejecuciones separadas y no se
suman; antes de separar los jobs se midió 91,05 % de líneas en la suite conjunta.
Además pasaron **239 E2E en 20 suites** y **23 pruebas de integración Material
sin skips**. No se midió cobertura de esas ejecuciones backend E2E/integración.
Las integraciones bloqueadas de Auth/Gateway sí fallaron, como registra el
[inventario](E2E_INVENTORY.md). Las ejecuciones locales de Backend y Web
seleccionadas para CI pasaron; Mobile sigue sin verificarse. npm emitió avisos de dependencias
deprecadas del backend (por ejemplo glob y ESLint); no se actualizaron porque
quedan fuera de este cambio.

El entorno local no dispone de Flutter: no se ejecutó Mobile ni se midió su
cobertura. Queda por comprobar ese job en un runner con el SDK registrado.
`actionlint` 1.7.7 validó el nuevo workflow sin errores. Se revisaron los scripts
invocados, la propagación de errores, los archivos cambiados y la conservación
del workflow de Kubero. **No se ha comprobado ningún run real en GitHub**;
la validación local no confirma la descarga del SDK ni la subida de artifacts
en GitHub Actions.

## Pendientes de Semana 4

- Nuevas unitarias/E2E de Material y nuevas pruebas de Search.
- Regresión completa de Catalog.
- Nuevos E2E del flujo Gateway → Material/Search/Catalog.
- Integración Web de subida y búsqueda; navegación Material → Detalle → Descarga.
- Regresión completa de integración Web.
- Revisar las zonas sin cobertura señaladas por los reportes de Gateway,
  Material, Web y los demás servicios; los porcentajes no garantizan todos los
  escenarios funcionales.
- Resolver posibles fallos funcionales con sus responsables, sin debilitar
  pruebas. No se implementa Quality Service ni trabajo pendiente de integrantes.

Este cambio no agrega pruebas ni ejecuta las regresiones completas anteriores.

## Protección de main después de estabilizar los checks

1. Publicar la rama y abrir un PR hacia `main`. Comprobar runs reales,
   incluyendo Mobile y la disponibilidad de los artifacts.
2. Cuando los checks sean estables, un administrador puede ir a **Settings →
   Rules → Rulesets** (o **Branches → Branch protection rules**) y seleccionar
   `main` como rama protegida.
3. Exigir PR y checks antes del merge. Seleccionar los nombres que GitHub
   muestre tras los runs: **Backend tests**, **Frontend tests**, **Mobile tests**,
   **Backend E2E (api-gateway)**, **Backend E2E (auth-service)**,
   **Backend E2E (catalog-service)**, **Backend E2E (material-service)**,
   **Frontend integration** y **Material integration**. No exigir las suites
   bloqueadas de Auth/Gateway integration ni Mobile live/nativa hasta resolver
   sus bloqueos y validarlas.
4. Conservar las reglas y checks existentes, incluidos los de Kubero si ya
   fueran obligatorios. Considerar exigir rama actualizada con `main` según la
   política del equipo. No habilitar merge queue sin añadir antes su evento
   `merge_group` al workflow.

No se aplican reglas desde esta tarea ni se hace merge.

## Referencias

- [Cobertura de Vitest](https://vitest.dev/guide/coverage.html).
- [Configuración y caché de Node en Actions](https://github.com/actions/setup-node).
- [Instalación y caché de Flutter en Actions](https://github.com/subosito/flutter-action).
- [PostgreSQL desechable en Actions](https://docs.github.com/en/actions/tutorials/use-containerized-services/create-postgresql-service-containers).
