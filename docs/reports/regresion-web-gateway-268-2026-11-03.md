# Regresión Web → Gateway #268 — 2026-11-03

**Resultado: 7/7 flujos aprobados en Chromium contra los cinco servicios reales,
PostgreSQL y MinIO.** No se interceptó ni simuló `fetch`, HTTP, Prisma o almacenamiento.

## Ejecución y entorno

- Inicio: 2026-11-03T00:34:48.600000-03:00 (America/Santiago); UTC original en el JSON.
- Código de aplicación: `9b9bbf07a77b8266c9ffade96cc9da11a780f062`. Script nuevo incluido con este informe;
  SHA-256: `32e8afda7f306447ac1c7ad4cf46ebd81987c0ae51964b98c55c06334398e454`.
- Sistema: linux 7.0.0-38-generic; Node v22.22.3; Playwright 1.63.0; Chromium 153.0.8010.12.
- Web: `http://127.0.0.1:36707`; `VITE_API_URL=http://127.0.0.1:43647/api/v1`.
  Puertos efímeros de esta ejecución, ya detenidos.
- Healthchecks: Auth, Catalog, Material, Search y Gateway respondieron **200**.
- PostgreSQL 17 y MinIO en contenedores nuevos; esquemas separados para Auth,
  Catalog y Material. La imagen MinIO se construyó previamente con
  `deploy/kubero/minio.Dockerfile`; los IDs exactos de imágenes están en el JSON.
- Se compiló el backend con `cd backend && npm run build` antes de ejecutar.
- Los servicios y la Web se iniciaron como procesos locales con configuración
  de prueba explícita. No se reutilizaron bases, buckets ni servicios existentes.

## Resultados observados

| Flujo | HTTP | Resultado | Captura |
| --- | --- | --- | --- |
| catalogo | 200 | PASS | [catalogo.png](evidence/268-2026-11-03/catalogo.png) |
| login | 200 | PASS | [login.png](evidence/268-2026-11-03/login.png) |
| subida | 201 | PASS | [subida.png](evidence/268-2026-11-03/subida.png) |
| listado | 200 | PASS | [listado.png](evidence/268-2026-11-03/listado.png) |
| detalle | 200 | PASS | [detalle.png](evidence/268-2026-11-03/detalle.png) |
| descarga | 200 | PASS | [descarga.png](evidence/268-2026-11-03/descarga.png) |
| busqueda | 200 | PASS | [busqueda.png](evidence/268-2026-11-03/busqueda.png) |

- Catálogo mostró la asignatura sintética QA268 y los selectores cargaron sus
  referencias desde el Gateway.
- Login mostró éxito, devolvió un token con `mock: true` y no persistió sesión
  en `localStorage` ni `sessionStorage`. El token no se guardó en la evidencia.
- Subida creó `284950df-45f8-41ed-ae0d-7ecb643e3b55`, título
  `Regresion268 qa268-c2a899c4`, en `PENDING_REVIEW`, versión 1 y objeto real en MinIO.
  Se habilitó el contexto local de autor exclusivamente en el proceso de prueba.
- Para las lecturas públicas se cambió **solo ese fixture** a `PUBLISHED` mediante
  Prisma en la base desechable. Esto prepara datos; no valida moderación.
- Listado y búsqueda devolvieron el mismo ID y lo mostraron en la Web. Detalle
  respondió 200 y mostró el título del material.
- Descarga mediante el botón del navegador produjo `regresion268.pdf`, de 414
  bytes, idéntico byte por byte al PDF subido, con `Content-Disposition` expuesto.
  SHA-256: `a2b4945b6565b105cbf8ab4dc1d86bfc925d1e3eaa91cfb6ea770d292c333d28`.

## Tráfico, incidencias y límites

Se registraron **25 peticiones fetch/XHR**, todas bajo la URL
configurada del Gateway, y **17 respuestas HTTP**, todas exitosas.
No hubo errores JavaScript de página ni dependencias del navegador hacia puertos
internos de microservicios en estos recorridos.

El modo desarrollo con React StrictMode canceló **8 consultas**
con `net::ERR_ABORTED` durante los montajes de listado/detalle/búsqueda. Cada URL
cancelada también obtuvo una respuesta 2xx y el contenido se mostró. El script
conserva esas cancelaciones en `failedRequests` y exige respuesta exitosa para
cada una; no las elimina del registro ni las considera un fallo funcional.
Para reproducirlas, ejecutar el script con Vite en desarrollo tal como se indica
abajo y observar las consultas duplicadas/canceladas en el JSON.

Durante la preparación se corrigieron dos problemas del **script de QA**:
la ruta compilada de Auth (`dist/src/main.js`) y la aserción que inicialmente
trataba cualquier cancelación de StrictMode como error. La ejecución final usa
el script corregido. No se modificó el código funcional de la aplicación.

No se detectaron incidencias funcionales en los siete escenarios ejecutados.
El alcance es Chromium de escritorio, archivo PDF y login mock; no acredita otros
navegadores, todos los formatos de archivo, moderación o autenticación real.
La suite es local y no está incorporada a CI.

## Evidencia y limpieza

- [Registro completo JSON](evidence/268-2026-11-03/report.json): fecha, commit,
  huella del script, IDs de imágenes, healthchecks, fixtures, peticiones,
  respuestas, cancelaciones y limpieza.
- [PDF original](evidence/268-2026-11-03/fixture.pdf) y
  [PDF descargado](evidence/268-2026-11-03/descarga.pdf), ambos sintéticos.
- Capturas por flujo enlazadas en la tabla anterior.
- Los dos contenedores y sus volúmenes se eliminaron al terminar; los procesos
  iniciados por el script fueron detenidos. Los servicios preexistentes no se
  modificaron. Los logs de arranque quedan en el directorio local de ejecución,
  no se adjuntan configuraciones `.env`, tokens ni credenciales privadas.

## Repetir desde Linux/Bash

Requisitos: Node.js 22, Docker y dependencias instaladas en `backend` y `web`.
Desde la raíz (la instalación de Playwright se mantiene fuera del proyecto):

```bash
npm --prefix backend ci
npm --prefix web ci
npm --prefix backend run build
docker build -f deploy/kubero/minio.Dockerfile -t apuntesuct/pr-test-minio:local .
npm install --prefix /tmp/apuntes-qa268-tools playwright@1.63.0
PLAYWRIGHT_BROWSERS_PATH=/tmp/apuntes-qa268-browsers \
  /tmp/apuntes-qa268-tools/node_modules/.bin/playwright install chromium
QA_PLAYWRIGHT_MODULE=/tmp/apuntes-qa268-tools/node_modules/playwright \
PLAYWRIGHT_BROWSERS_PATH=/tmp/apuntes-qa268-browsers \
QA_OUTPUT_DIR=/tmp/apuntes-qa268-results \
  node .github/scripts/web-gateway-regression.cjs
```

Chromium requiere sus bibliotecas del sistema instaladas. En esta ejecución se
reutilizó Playwright 1.63.0 y Chromium ya disponibles localmente. El script
crea infraestructura y datos nuevos en cada ejecución; devuelve código distinto
de cero si falla una comprobación o la eliminación de sus contenedores.
`QA_MINIO_IMAGE` permite seleccionar otra imagen local compatible; por defecto
usa la imagen construida con el Dockerfile del repositorio. `QA_OUTPUT_DIR`
debe apuntar a un directorio nuevo para conservar separadas las evidencias.
