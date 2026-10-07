# Revisión general y mantenimiento — 5 de octubre de 2026

Estado final en `fix-revision-catalogo-paleta-seguridad`. Se revisaron contratos,
catálogo, relación profesor–asignatura, configuración, paleta y dependencias npm.
Este informe reemplaza los conteos intermedios de la revisión.

## Seguridad de dependencias

| Proyecto | Antes | Intermedio | Final completo | Final producción |
| --- | ---: | ---: | ---: | ---: |
| Backend | 45 (1 crítica) | 3 altas | **0** | **0** |
| Web | 9 | 5 altas | **0** | **0** |

Resultados de `npm audit --json` y `npm audit --omit=dev --json` contra el registro.
Cero alertas npm significa cero vulnerabilidades conocidas reportadas en ese
momento, no una garantía de seguridad de todos los flujos de la aplicación.

- Se actualizaron NestJS a 11.2.7 y Jest a 30.5.2, y dependencias compatibles.
- Se conservan overrides documentados para Swagger → `js-yaml` 5.4.3, lector de
  cobertura → `js-yaml` 4.3.2 y Prisma config → `deepmerge-ts` 8.0.0. Estos cambios
  transitivos se verificaron con generación de Prisma, build y pruebas.
- Se retiró `http-proxy-middleware` y se utiliza directamente `httpxy` 0.5.5,
  el mismo motor HTTP que ya dependía de él. Nest selecciona las rutas públicas;
  no se necesita la cadena `micromatch` → `braces` para patrones glob. Se mantienen
  las rutas existentes de Auth/Catalog, headers, cookies, métodos, query, JSON,
  formularios, streams sin procesar, timeout y errores 502. Para cuerpos ya
  consumidos por Nest se reconstruye el stream y se actualizan sus headers.
- Se migró web de Tailwind 3.4.19 a **4.3.3**, con `@tailwindcss/vite` 4.3.3.
  Se retiraron la configuración PostCSS antigua, Autoprefixer y el override de
  `postcss-selector-parser`. La cadena vulnerable de herramientas CSS desaparece.
  Se conserva la configuración de colores, se adaptan nombres de utilidades y
  se mantienen defaults de bordes/placeholders/cursor para limitar cambios visuales.
- Ya no se instalan `braces` ni `micromatch` en ninguno de los dos árboles npm.

La migración a Tailwind 4 establece como mínimo Safari 16.4, Chrome 111 y Firefox
128. No se comprobó compatibilidad con navegadores anteriores. Referencias:
[guía de Tailwind](https://tailwindcss.com/docs/upgrade-guide),
[documentación de httpxy](https://github.com/unjs/httpxy),
[aviso de braces sin parche](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm),
[cambios de deepmerge-ts 8](https://github.com/RebeccaStevens/deepmerge-ts/releases/tag/v8.0.0).

## Separación del Sprint 2

Se contrastaron los cambios nuevos con la planificación aportada por el usuario.
No se interpretan las casillas del documento como estado actualizado de GitHub.

Se guardó un respaldo completo anterior a la separación en la rama local:

`backup/revision-antes-separar-sprint2`

Commit: `ee92748631c77f3d4a28d7d33ed9da8e8c9f5fde`.

El respaldo contiene el estado previo completo, incluyendo mantenimiento; no es
un PR de Sprint 2 listo para fusionar. Permite recuperar selectivamente el trabajo.
No se publicó ninguna rama ni se modificó el historial de main.

**Retirado al separar el alcance el 5 de octubre y conservado en el respaldo:**

- Los cuatro endpoints académicos y sus nuevas pruebas: corresponden a David,
  semana 1, «Completar Catalog Service y separar definitivamente Material/Search».
- El proxy de Material, variable de entorno, índice Swagger y prueba específica:
  corresponden a David, semana 1, «Incorporar Material y Search al API Gateway».
- La conexión funcional del panel de filtros del catálogo, dependiente de esos
  endpoints. El panel conserva el comportamiento previo de main con datos mock;
  no debe presentarse como filtrado real. Su integración queda para el sprint.

Los selectores reutilizables y los componentes de Material ya estaban en main.
Sus cambios restantes aquí son de paleta y compatibilidad con Tailwind. Tampoco
se crearon nuevos servicios Material/Search ni se implementaron subida, descarga,
versionado, búsqueda o endpoints de moderación.

Al separar el alcance el 5 de octubre, el proxy conservó únicamente las rutas
públicas existentes de Auth/Catalog. Material/Search quedaron a cargo de la tarea
correspondiente del sprint.

### Actualización del 6 de octubre: integración del proxy de main

El merge local `d298a3f` incorpora la tarea #222 ya integrada por el equipo en
main (`1c14b99`). Ahora el Gateway también enruta `/api/v1/materials` y
`/api/v1/search`, con sus variables de entorno y errores `502` propios.
La resolución conserva `httpxy` y las correcciones de seguridad de esta rama.
Se adaptaron las pruebas que dependían de la librería anterior y se retiró la
expectativa obsoleta de que esas dos rutas devolvieran `404`.

Validación de la integración: compilación y lint del Gateway aprobados,
21 pruebas unitarias y 41 pruebas HTTP aprobadas; auditoría del backend con
0 vulnerabilidades reportadas. Las pruebas de Material/Search usan servidores
simulados: no acreditan todavía el flujo real de subida, almacenamiento y descarga.
El POST de Material sigue siendo un contrato simulado. No se implementaron
persistencia, MinIO ni funcionalidades de semanas posteriores al resolver el merge.

## Correcciones conservadas

- **Dato profesor–asignatura:** en la base local había un recurso del seed cuyo
  profesor no estaba conectado a su asignatura en `_ProfessorToSubject`. Se
  contrastó con el ejemplo exacto del seed (ICI-314 y su profesor) y se restauró
  únicamente esa asociación en una transacción. La consulta posterior devolvió
  **0 recursos con profesor no asociado**. Es un cambio en la base local separado
  de Git; no se borraron datos ni se ejecutó el seed completo.
- **Catálogo existente:** árbol y filtro excluyen entidades inactivas; creación
  de asignaturas conserva `description` y `active`, que antes se descartaban.
- **Contrato web:** la respuesta de asignaturas por carrera se adapta al modelo
  de presentación existente, en vez de afirmar un tipo incompatible con el JSON.
- **Prisma:** auth y catálogo generan clientes independientes, evitando colisiones
  en un workspace compartido. Material ya utilizaba una salida propia. El seed
  de catálogo se configura en `prisma.config.ts`, eliminando el aviso obsoleto.
- **Instalación:** un solo `backend/package-lock.json` para todos los workspaces;
  se retiraron tres lockfiles internos obsoletos y se documentó `npm ci` desde
  backend. Se eliminó la clave `version` obsoleta de Docker Compose.
- **Paleta:** se usan los colores del tema claro de
  `mobile/lib/core/theme/uct_palette.dart`: azul `#0078BC`, celeste `#3DA5D9`, navy
  `#0F1D34`, amarillo `#FEC601` y superficies claras. Se conserva la marca de Google.
  No se agregó un selector de tema oscuro a web.
- **Login:** utiliza la misma URL local predeterminada del Gateway que catálogo.

## Validaciones

- Build Nest/TypeScript de los cinco servicios y build Vite de web.
- Backend: **55 pruebas unitarias**; Search aún no posee pruebas.
- Web: **34 pruebas**, incluyendo el panel previo y selectores existentes.
- Gateway: **26 pruebas HTTP**, incluyendo JSON, formularios Unicode, gzip,
  bytes de entrada/salida, cookies, errores, rutas y acceso a controladores Auth.
- ESLint de backend y web, generación de tres clientes Prisma.
- Auditorías completas y de producción; `npm ci --dry-run` de ambos lockfiles.
- No se ejecutaron migraciones ni operaciones destructivas en la base.
- Se verificó visualmente el catálogo en Firefox headless a 1280 × 900.
- Flutter no está instalado; no se ejecutaron sus pruebas.

## Limitaciones de producto pendientes

Estas limitaciones no desaparecen por tener cero alertas de dependencias:

1. El login sigue siendo mock y entrega tokens sin firma. El Sprint 2 contempla
   conservar ese login durante su regresión. Las escrituras de catálogo siguen
   sin un guard de autorización real; no son aptas como API pública de producción.
2. La validación de referencias de Material pertenece a Antonio, semana 2.
   No hay que ampliar el modelo `Resource` de Catalog como fuente de materiales.
3. El plan ya define que Material posee los materiales y Search realiza búsqueda
   y filtros Año/Tipo. La promesa obsoleta de esos filtros en Catalog debe retirarse
   en la tarea de separación de dominios de David, semana 1.
4. Detalle/descarga, subida y demás integraciones nuevas continúan como tareas del
   Sprint 2. Las pantallas que solo tenían maqueta no ganaron esos comportamientos.
5. Mobile conserva mocks y puede representar una universidad sin carreras como
   asignatura; su repositorio también convierte ciertos errores de formato en una
   lista vacía. Debe revisarse con pruebas Flutter.
6. Catalog continúa arrancando aunque falle la conexión Prisma, y su health
   superficial no garantiza que la base esté disponible.
