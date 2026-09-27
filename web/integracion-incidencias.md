# Bitácora de Pruebas de Integración (Frontend)

## Contexto (Issue #128)

Este documento registra el proceso de ejecución y verificación de pruebas de integración del frontend (React/TypeScript) contra los endpoints principales de la aplicación, enfocándose en asegurar la correcta respuesta y el manejo de estados de la UI (Spinner de carga, Alertas de error).

## Pruebas Implementadas

Se ha implementado una suite de pruebas de integración utilizando `Vitest` y `@testing-library/react` en el archivo `web/src/presentation/pages/CatalogPage.integration.test.tsx`.

### Casos de Prueba Verificados

1. **Estado de Carga (Spinner/Skeleton):**
   - Se simuló el retraso en la respuesta de la API usando promesas no resueltas en el cliente `fetch`.
   - **Resultado:** ✅ Éxito. La interfaz muestra correctamente los esqueletos animados (`animate-pulse`) o el mensaje de estado "Cargando asignaturas…" antes de que se resuelva la consulta de `react-query`.
2. **Manejo de Errores (API caída o Error 500):**
   - Se simuló una respuesta con `ok: false` y `status: 500` desde el servicio de catálogo (simulando que `:3002/api/v1/catalog/filter` está inactivo).
   - **Resultado:** ✅ Éxito. La interfaz cambia a estado de error de forma controlada gracias a React Query (`isError`), mostrando el mensaje "No se pudo cargar el catálogo" y "Intenta recargar la página en unos minutos", sin arrojar excepciones no manejadas en consola.
3. **Validación de Contratos y Renderizado de Datos:**
   - Se simuló una respuesta exitosa con código `200` y con la estructura esperada según el modelo de datos (lista de `RawCatalogSubject` con relaciones como `career` y `professors`).
   - **Resultado:** ✅ Éxito. Los componentes hijos (`CatalogGrid`) renderizan correctamente el nombre, código y semestre de la asignatura desde el endpoint.

## Incidencias y Desajustes Encontrados

Durante la prueba manual inicial de los endpoints en tiempo real, se registraron las siguientes incidencias:

1. **Disponibilidad del Backend en Entorno de Pruebas:**
   - **Observación:** El endpoint real en `http://localhost:3002/api/v1/catalog/filter` no responde o produce _Connection Refused_ si los microservicios (catalog-service y api-gateway) no han sido levantados mediante Docker Compose y poblados (seeding).
   - **Resolución Temporal:** Para permitir integración continua fiable desde la web, las pruebas de UI (`CatalogPage.integration.test.tsx`) utilizan `vi.spyOn(global, 'fetch')` para mockear la respuesta de red garantizando que la UI reacciona adecuadamente ante los contratos del backend descritos en la documentación sin depender de los contenedores levantados.

2. **Detalles de Contrato de Error:**
   - **Observación:** La API suele devolver objetos de error `{ statusCode, message, error }`. Si la comunicación falla drásticamente (CORS, offline, o 502 Bad Gateway) la respuesta puede omitir la propiedad `error`.
   - **Validación:** El frontend delega en el bloque `!response.ok` en `catalogApi.ts` arrojando un objeto `Error` de JS genérico. Esto es suficiente para que `React Query` active el estado `isError`, aunque se recomienda estandarizar el consumo de mensajes del API si se planean mostrar al usuario final en el futuro. Actualmente la UI usa el texto harcodeado "No se pudo cargar el catálogo".

## Conclusión

La integración del listado del catálogo es robusta frente a estados intermedios. Los Spinners y Alertas de error funcionan según lo esperado, cumpliendo con los criterios requeridos para la Issue #128.
