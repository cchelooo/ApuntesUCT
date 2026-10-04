# Issue #271 — dominio Mobile de materiales

Rama: `feature/271-dominio-materiales`.

## Día 1 — 3 de octubre de 2026

Se añadieron `AcademicReference`, `MaterialStatus` y fixtures con pruebas de
referencia completa, mínima e inválida y estados, incluyendo `PENDING_REVIEW`.

## Día 2 — 4 de octubre de 2026

Implementación Mobile terminada para trabajar con datos locales:

- `MaterialSummary` conserva los parámetros de #284 e incorpora referencias
  académicas por ID/nombre, usuario que subió el material y estado interpretable.
- `MaterialDetail` incorpora historial y versión actual.
- `MaterialVersion` contiene identidad, material, número de versión y metadatos
  opcionales de archivo, autor y fecha.
- `MaterialPage` contiene items, página, tamaño y total, y permite saber si
  quedan páginas. Las colecciones del detalle y página son inmutables.
- `MaterialRepository` separa listado, detalle, subida, descarga y versionado.
- `SearchRepository` recibe texto y filtros académicos con paginación, sin
  mezclar búsqueda con las operaciones de Material Service.
- Las entradas de subida admiten archivo local o enlace externo. Los archivos
  y descargas se representan mediante bytes y metadatos, sin Dio ni widgets.
- Las tarjetas muestran estados en español y no muestran un año inventado.

El parseo rechaza identidades vacías, tipos incompatibles, contadores negativos,
fracciones en campos enteros, fechas inválidas y versiones de otro material.
Un estado ausente o desconocido nunca se interpreta como aprobado. Año, fecha
u otros metadatos opcionales ausentes no se fabrican a partir del momento actual.

## Contrato de Backend pendiente

Las dependencias #217, #218 y #219 siguen abiertas. El PR #311 inicializa el
servicio y documenta su healthcheck; no define DTOs de materiales, versiones,
subida ni listado paginado. Por eso el JSON de los fixtures es un formato interno
provisional, respaldado por los requisitos y el MER; no es una respuesta real
capturada del Gateway ni evidencia de compatibilidad con OpenAPI.

Antes de cerrar la issue deben verificarse contra el contrato publicado:

- nombres, campos obligatorios/opcionales y códigos de estado;
- envoltura de paginación y referencias académicas del transporte;
- DTOs de versión, subida multipart/enlace y respuesta de descarga.

El futuro adaptador HTTP traducirá esos DTOs al dominio. Las validaciones del
archivo y metadatos deberán respetar #219, incluyendo MIME y límite de 15 MB.
Las horas y el estado de la issue no se modificaron desde este avance.

## Compatibilidad con #283

Las tarjetas y las pruebas de descubrimiento del PR #307 compilan y pasan con
estos modelos. Su `MaterialsRepository` plural es un prototipo diferente del
contrato definitivo `MaterialRepository`: en la integración deberá usarse
`SearchRepository` para búsqueda/filtros y `MaterialRepository` para operaciones
sobre materiales. No se modificó ni integró el PR #307 desde esta rama.

## Formato interno de fixtures

| Modelo | Identidad/metadatos mínimos del formato interno |
|---|---|
| MaterialSummary | `id`, `title`; estado ausente significa desconocido |
| MaterialDetail | Los mismos campos y colecciones opcionales `tags`, `versions` |
| MaterialVersion | `id`, `materialId`, `versionNumber` mayor o igual a 1 |
| MaterialPage | `items`, `page`, `pageSize`, `total` |

Las referencias usan IDs lógicos (`universityId`, `careerId`, `subjectId`,
`professorId`) con nombres mostrados opcionales. El formato no impone relaciones
SQL entre bases de microservicios. Los códigos distintos de `PENDING_REVIEW`
y su correspondencia de transporte deberán confirmarse con INT2.

## Validación

Desde `mobile/`:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Resultados del día 2:

- Formato y análisis sin errores.
- 96 pruebas de Mobile aprobadas; 30 corresponden a materiales.
- 33 pruebas de materiales aprobadas al combinar temporalmente los modelos
  con la pantalla del PR #307, incluido análisis sin errores.
- Ejecución de modelos y tipos de repositorio con Dart, sin motor Flutter/Dio.
- Navegación a detalle a 320 px con estado de revisión y año ausente sin overflow.

Fixtures: `mobile/test/fixtures/materials/domain_foundations.json` y
`mobile/test/fixtures/materials/domain_models.json`. Los fixtures visuales en
`MaterialFixtures` conservan los dos materiales usados por #284/#283 e incluyen
referencias, versión y página de ejemplo.
