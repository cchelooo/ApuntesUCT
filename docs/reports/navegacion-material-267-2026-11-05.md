# Validación Material → Detalle → Descarga #267

**Resultado: PASS. Los 11 escenarios de navegador aprobaron contra servicios
reales el 5 de noviembre de 2026, entre las 16:33:53 y 16:34:04 de Santiago.**
Complementa las pruebas del PR #496 con evidencia de integración.

La ejecución fue automatizada con Playwright en Chromium; no se presenta como
una sesión manual. No se interceptaron peticiones ni se simularon respuestas
HTTP, PostgreSQL o MinIO. Se revisó visualmente la captura del error de descarga.

## Criterios de aceptación

| Criterio | Comprobación y evidencia | Resultado |
| --- | --- | --- |
| Navegación con IDs reales | Material creado por POST, persistido y devuelto por listado/búsqueda. Se comprobó el enlace de cada tarjeta y se hizo clic para abrir el detalle con ese mismo ID. [Biblioteca](evidence/267-2026-11-05/listado.png), [Búsqueda](evidence/267-2026-11-05/busqueda.png). | PASS |
| El detalle carga correctamente | HTTP 200, ID coincidente y título visible al entrar desde Biblioteca y Búsqueda. [Detalle](evidence/267-2026-11-05/detalle.png). | PASS |
| Descarga mediante Gateway | Botón del navegador, HTTP 200 y archivo idéntico byte por byte al PDF original desde ambos recorridos. Las 36 peticiones fetch/XHR usaron el Gateway configurado. [Registro HTTP](evidence/267-2026-11-05/report.json). | PASS |
| 404 controlado en detalle | UUID inexistente devuelve 404, muestra «No encontramos este material», oculta la descarga y permite volver al catálogo. [Mensaje](evidence/267-2026-11-05/detalle-404-mensaje.png), [retorno](evidence/267-2026-11-05/detalle-404.png). | PASS |
| Error de descarga controlado | Se eliminó únicamente el objeto del fixture en MinIO. La descarga devolvió 404, mostró alerta y «Reintentar descarga», conservó el detalle y no produjo archivo. [Error](evidence/267-2026-11-05/descarga-404.png). | PASS |
| Reintento | Se restauró el objeto original y se pulsó «Reintentar descarga». HTTP 200, alerta retirada y PDF idéntico al original. [Reintento](evidence/267-2026-11-05/descarga-reintento.png). | PASS |

## Entorno y material

- Código de aplicación: `afe5156f2edf097816d9efd929934a5aadde70ae` (PR #496).
  La ampliación del script de QA acompaña este informe, sin cambios funcionales.
- Script: `.github/scripts/web-gateway-regression.cjs` con
  `QA_MATERIAL_NAVIGATION=1`; SHA-256 de la ejecución:
  `6ada609b594d718adb2ddd4f64c56de729144c2f7dd2e77f518cdb5f212221e4`.
- Node 22.22.3, Playwright 1.63.0, Chromium 153.0.8010.12, Linux.
- Auth, Catalog, Material, Search y Gateway: healthchecks 200.
- PostgreSQL 17 y MinIO en contenedores nuevos, con esquemas y bucket desechables.
- Web: `http://127.0.0.1:42295`; Gateway: `http://127.0.0.1:46241/api/v1`.
  Son puertos temporales de una ejecución ya detenida.
- Material: `4eac0918-b2c6-448e-b015-df02bf8c707a`.
- Versión: `2f8e8ba1-2087-4a82-8b57-e6bd7fc76479`.
- Título: `Regresion268 qa268-ca558e4f`. El prefijo QA268 se conserva porque
  se reutilizó la infraestructura de regresión de #268.
- Se subió un PDF sintético mediante la UI. Se habilitó el autor local de
  desarrollo y se publicó solo ese fixture mediante Prisma en la base nueva.
  Esta preparación no valida moderación ni autenticación real.

El PDF tiene 414 bytes, nombre de descarga `regresion268.pdf` y SHA-256
`a2b4945b6565b105cbf8ab4dc1d86bfc925d1e3eaa91cfb6ea770d292c333d28`.
Las tres descargas coinciden con el original:

- [PDF original](evidence/267-2026-11-05/fixture.pdf).
- [Descarga desde Biblioteca](evidence/267-2026-11-05/descarga.pdf).
- [Descarga desde Búsqueda](evidence/267-2026-11-05/busqueda-descarga.pdf).
- [Descarga tras reintentar](evidence/267-2026-11-05/reintento.pdf).

## Resultados y límites

El registro contiene 11 escenarios PASS, 25 respuestas HTTP (23 exitosas y
los dos 404 esperados), tres descargas y cero errores JavaScript de página.
Las 11 cancelaciones `net::ERR_ABORTED` corresponden a consultas de desarrollo
con React StrictMode; todas sus URL también recibieron la respuesta esperada.
Se conservan en el JSON, incluida la consulta del detalle inexistente.

También aprobaron la compilación del backend y las nueve pruebas de
`MaterialNavigation.test.tsx`. No hubo incidencias funcionales en los recorridos.
Esta ejecución acredita Chromium de escritorio y PDF en entorno local real;
no valida el despliegue productivo, otros navegadores ni autenticación real.
El 503 y el fallo de red siguen cubiertos por la suite simulada del PR, no por
esta ejecución de integración. El login de la regresión usa el mock existente.

Los procesos del script se detuvieron y sus dos contenedores se eliminaron con
sus volúmenes; la limpieza está registrada en el JSON. No se modificaron los
servicios preexistentes. Solo se adjuntan capturas, PDFs sintéticos y el registro
de evidencia, sin logs de configuración ni tokens.

## Reproducción

Requiere Docker, Node 22, dependencias de `backend` y `web` instaladas y las
bibliotecas del sistema necesarias para Chromium. Desde la raíz:

```bash
npm --prefix backend run build
docker build -f deploy/kubero/minio.Dockerfile -t apuntesuct/pr-test-minio:local .
npm install --prefix /tmp/apuntes-qa267-tools playwright@1.63.0
PLAYWRIGHT_BROWSERS_PATH=/tmp/apuntes-qa267-browsers \
  /tmp/apuntes-qa267-tools/node_modules/.bin/playwright install chromium
QA_PLAYWRIGHT_MODULE=/tmp/apuntes-qa267-tools/node_modules/playwright \
PLAYWRIGHT_BROWSERS_PATH=/tmp/apuntes-qa267-browsers \
QA_OUTPUT_DIR="$(mktemp -d /tmp/apuntes-qa267-results-XXXXXX)" \
QA_MATERIAL_NAVIGATION=1 \
  node .github/scripts/web-gateway-regression.cjs
npm --prefix web run test:run -- src/presentation/pages/MaterialNavigation.test.tsx
```

El script crea un material e infraestructura nuevos en cada ejecución. Para
repetir manualmente contra un entorno de pruebas propio: subir y publicar un
material, abrir su tarjeta desde Biblioteca y Búsqueda, comprobar el mismo ID
en el detalle, descargar y comparar el PDF. Abrir después un UUID inexistente;
para el error de descarga, retirar y restaurar únicamente el objeto del material
de prueba antes de pulsar «Reintentar descarga». Nunca usar datos compartidos
para provocar estos fallos.
