# Regresión de Gateway, backend y web — 6 de octubre de 2026

Rama: `fix-revision-catalogo-paleta-seguridad`, después de integrar main en
`d298a3f`. Revisión limitada a las capacidades existentes; no implementa tareas
futuras de subida persistente, MinIO, descarga, búsqueda o moderación.

## Correcciones encontradas mediante pruebas

- Auth y Catalog: `start:prod` apuntaba a `dist/main`; la compilación genera
  `dist/src/main.js`. Se corrigieron los scripts y ambos arrancaron en puertos de
  prueba, respondiendo su health con `200`.
- Material rechazaba exactamente 15 MB aunque el contrato permite ese tamaño.
  Ahora acepta 15 728 640 bytes y rechaza un byte adicional con `413`.
- La recepción no tenía un límite Multer de archivo: se agregó para cortar
  archivos excesivos durante la recepción, antes de cargar todo su contenido.
- La detección genérica de Nest no distinguía DOC/PPT dentro de CFB y los rechazaba.
  Se agregó `cfb@1.2.2` para comprobar sus streams; se mantienen detección de
  contenido para PDF/DOCX/PPTX y rechazo de XLS/CFB corrupto/MIME falsificado.
  La respuesta usa el MIME detectado, no el declarado por el cliente.
- Configuración **solo local**: Catalog tenía `PORT=3001`; se corrigió a `3002`.
  Material no tenía `.env` ni tablas en su base local. Se creó la configuración
  a partir de `.env.example` y se aplicó la migración existente al esquema vacío.
  `GET /api/v1/materials` pasó de `500` por tabla inexistente a `200`.

## Resultados automatizados

| Grupo | Resultado |
| --- | --- |
| Backend unitario | 84 aprobadas: Gateway 21, Auth 35, Catalog 16, Material 12 |
| Web | 39 aprobadas en 9 archivos |
| Gateway HTTP | 42 aprobadas |
| Auth HTTP | 18 aprobadas |
| Catalog HTTP y migración | 6 aprobadas |
| Material HTTP | 26 aprobadas |
| Gateway → controlador real POST Material | 13 aprobadas (12 casos y suite contenedora) |
| Material con PostgreSQL | 7 aprobadas (incluye suites contenedoras) |

Total reportado por los ejecutores: **235 pruebas aprobadas**. Search aún no tiene
pruebas unitarias propias; sus rutas y respuestas se comprobaron por Gateway.
Compilan los cinco servicios y web; lint sin errores ni advertencias.
También se verificó `npm ci --ignore-scripts` desde el lockfile limpio del backend,
seguido de compilación, pruebas unitarias, lint y pruebas Gateway/contrato: todo aprobado.

Las pruebas nuevas cubren formatos, tamaño exacto/exceso, multipart, Unicode,
MIME detectado, reglas de archivo/enlace, errores y servicio caído. El proxy
conserva bytes y cabeceras de descarga de un servidor simulado. En web se agregaron
regresiones de login para `400`, `500`, `502`, red caída, doble envío y éxito.

Las pruebas de persistencia de Material usaron esquemas temporales y los eliminaron.
La prueba de migración Catalog también se ejecutó en un esquema temporal aislado,
sin crear ni borrar tablas en `public`.

## Navegador y servicios locales

Chromium automatizado: `/`, `/catalog`, `/login`, `/register`, `/search`,
`/library`, `/profile`, `/material/test` y una ruta inexistente. Se revisaron a
1440, 390 y 320 píxeles de ancho: **27 combinaciones sin excepciones JavaScript ni
desbordamiento horizontal**. Se inspeccionaron capturas de catálogo y autenticación.

Interacciones verificadas: catálogo con datos reales, búsqueda local por código,
resultado vacío, apertura de filtros móviles, login mock pasando por Gateway y
mensajes ante `400`, `502`, error de red y fallo del catálogo. Los errores se
simularon en el navegador; el caso exitoso consumió los servicios locales.

Por `localhost:3000` respondieron `200`: health del Gateway, health de Auth,
árbol/filtro de Catalog, listado Material, stub Search e índice Swagger.
El POST real sigue siendo un **stub**, aunque la validación y transporte son reales.

## Dependencias y límites de la revisión

`npm audit` completo: **0 vulnerabilidades reportadas en backend y web**, incluyendo
desarrollo. La incorporación de CFB mantiene ese resultado. Esto no garantiza que
no existan vulnerabilidades desconocidas o errores fuera de los casos probados.

- El login sigue siendo mock; no se implementó autenticación real ni autorización nueva.
- Registro/Google/recuperación y las pantallas pendientes mantienen su alcance previo.
- No se implementó separación Catalog/Material/Search ni se adelantaron funcionalidades
  asignadas a semanas posteriores.
- No se validó una descarga persistida desde MinIO ni búsqueda funcional: no existen aún.
- Los fixtures Office verifican identificación de contenedores, no renderización ni
  ausencia de contenido malicioso.
- Flutter no está instalado; esta revisión no certifica la aplicación Mobile.

## Reproducción principal

Desde `backend`:

```bash
npm ci --ignore-scripts
npm run build
npm run test:ci
npm run lint
npm run test:e2e --workspace=api-gateway -- --runInBand
npm run test:e2e --workspace=auth-service -- --runInBand
npm run test:e2e --workspace=catalog-service -- --runInBand --testPathIgnorePatterns=migration-semester
npm run test:e2e --workspace=material-service -- --runInBand
npm run test:integration --workspace=api-gateway
npm audit
```

Las pruebas de Catalog/Auth requieren la base local. Para las pruebas de persistencia
Material, definir `MATERIAL_TEST_DATABASE_URL` y ejecutar
`npm run test:integration --workspace=material-service`; los scripts aíslan sus esquemas.
La prueba de migración Catalog debe recibir `DATABASE_URL` con un esquema temporal,
como se hizo en esta revisión.

Desde `web`: `npm run build`, `npm run test:run`, `npm run lint`, `npm audit`.
