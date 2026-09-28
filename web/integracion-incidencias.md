# Bitácora de Pruebas de Integración (Frontend)

## Contexto (Issue #128)

Este documento registra el proceso de ejecución y verificación de pruebas de integración del frontend (React/TypeScript) contra los endpoints principales de la aplicación, enfocándose en asegurar la correcta respuesta y el manejo de estados de la UI (Spinner de carga, Alertas de error).

## Pruebas Implementadas

Se ha implementado una suite de pruebas de integración utilizando `Vitest` y `@testing-library/react` en el archivo `web/src/presentation/pages/CatalogPage.integration.test.tsx`.

### Directrices de Pruebas

Para garantizar la estabilidad y reproducibilidad de las pruebas automatizadas, las peticiones HTTP se han simulado en el entorno de pruebas.

- **Pruebas con Fetch Simulado (Mocked):** Utilizamos `vi.stubGlobal('fetch', ...)` para simular respuestas de la API de forma controlada. Es imperativo limpiar estos mocks tras cada prueba (mediante `vi.unstubAllGlobals()`).
- **Directrices para Endpoints Reales (Catálogo y Login):**
  - **Catálogo:** Los endpoints reales (`/api/v1/catalog/filter`) se prueban de forma manual o en pruebas E2E, debiendo asegurar que la infraestructura base y el microservicio de catálogo estén ejecutándose.
  - **Login:** De igual forma, el login requiere interactuar con el endpoint de autenticación real para validar la gestión de sesión y obtención de tokens.

### Casos de Prueba Verificados con Mocks

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

Durante la prueba de los endpoints reales, se registraron y documentaron las siguientes incidencias:

1. **Disponibilidad del Backend en Entorno de Desarrollo (Aclaración sobre Docker Compose):**
   - **Pasos:** Iniciar Docker Compose, abrir la aplicación web y navegar a la página de catálogo (o login) esperando respuesta del backend.
   - **Resultado Esperado:** La página debería mostrar el catálogo real y permitir inicio de sesión.
   - **Resultado Obtenido (Evidencia):** El endpoint en `http://localhost:3002/api/v1/catalog/filter` arroja _Connection Refused_.
   - **Resolución y Corrección de directrices:** Se aclaró la ejecución del backend. **Docker Compose levanta únicamente la infraestructura base** (Bases de datos, Redis, RabbitMQ, etc.). **Los microservicios correspondientes (Catalog, Auth, API Gateway) se ejecutan por separado** (vía scripts de NPM, ej. `npm run start:dev`). Por ello, las pruebas automatizadas del frontend se aíslan con mocks globales.

2. **Detalles de Contrato de Error:**
   - **Pasos:** Simular una interrupción en el API Gateway o un error de CORS, realizando una petición de catálogo.
   - **Resultado Esperado:** El cliente debería poder extraer el objeto de error estándar `{ statusCode, message, error }`.
   - **Resultado Obtenido (Evidencia):** En caídas drásticas (502 o CORS), la respuesta omite la propiedad `error`, lo que puede generar fallos en el frontend si asume que siempre existirá.
   - **Resolución:** El frontend maneja de manera genérica el fallo (bloque `!response.ok`), utilizando un mensaje de error estándar ("No se pudo cargar el catálogo") que permite al usuario saber qué ocurre sin romper la aplicación.

## Conclusión

La integración del listado del catálogo es robusta frente a estados intermedios. Los Spinners y Alertas de error funcionan según lo esperado, cumpliendo con los últimos ajustes de la Issue #128 en cuanto a manejo global de mocks y documentación de infraestructura.
