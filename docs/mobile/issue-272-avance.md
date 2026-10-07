# Issue #272 — Material y Catalog mediante Gateway

Rama local: `feature/272-gateway-material-catalog`.
Base del día 1: `origin/main`, commit `620698f`.
Base final: `origin/main`, commit `8736888` (PR #320 y #307 integrados).

## Día 1 — 6 de octubre de 2026

- `ApiConfig` conserva `API_GATEWAY_URL` como única configuración de entrada.
  Se elimina la resolución directa de Catalog y la lectura de
  `CATALOG_SERVICE_URL` en Mobile.
- Android Emulator utiliza `10.0.2.2:3000/api/v1`; simulador iOS y escritorio
  utilizan `localhost:3000/api/v1`. Un `API_GATEWAY_URL` explícito tiene prioridad.
- `catalogApiClientProvider` reutiliza `apiclientProvider`. Auth y Catalog
  comparten así el mismo cliente, configuración e interceptores.
- Un override del cliente central llega hasta `CatalogRepository` y la petición
  conserva la ruta `/api/v1/catalog` y el parseo del árbol académico.
- Un fake de Catalog sustituye al repositorio sin construir el cliente HTTP.
- Se actualizan los comandos de ejecución del README; la guía de integración
  de Sprint 1 queda marcada como referencia histórica para la configuración.

## Validación del día 1

Desde `mobile/`:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter test --dart-define=API_GATEWAY_URL=https://gateway.example.test/api/v1 \
  --dart-define=CATALOG_SERVICE_URL=http://localhost:3002/api/v1 \
  test/core/config/api_config_test.dart \
  test/features/catalog/data/catalog_gateway_provider_test.dart
```

- Formato y análisis sin errores.
- 103 pruebas Mobile aprobadas; 7 pruebas nuevas de configuración/providers.
- 22 pruebas dirigidas de configuración y Catalog aprobadas.
- Las 7 pruebas de configuración/providers también pasan con un Gateway
  personalizado y el antiguo define de Catalog: ese define ya no cambia el
  destino del cliente.

Las peticiones de estas pruebas utilizan un adaptador HTTP simulado. No prueban
un Gateway ni un Catalog Service levantados. Las comprobaciones de plataforma
utilizan la plataforma de Flutter sustituida en pruebas, no simuladores reales.

## Día 2 — 7 de octubre de 2026, implementación completada

- Se actualizó la rama con `origin/main` conservando los cambios del día 1.
  #222 está cerrada y el Gateway ya tiene el proxy real de Material.
- `materialApiClientProvider` comparte el cliente central con Auth y Catalog.
  `materialListingRepositoryProvider` permite sustituir el transporte por un
  fake; `materialListProvider(page)` expone carga, datos y error.
- `MaterialListingRepository` define la parte de lectura del contrato de #271,
  y `MaterialRepository` conserva todas sus operaciones e implementa esa
  interfaz. El adaptador Dio implementa únicamente el listado disponible;
  no inventa endpoints de detalle, subida, descarga o versionado.
- `DioMaterialListingRepository` consulta `/materials` con `page`/`pageSize`,
  valida los límites publicados, interpreta `{ items, page, pageSize, total }`
  y conserva código/mensaje de los errores HTTP. Una respuesta inválida se
  presenta como error, no como lista vacía.
- El dominio reconoce `PUBLISHED` y lo etiqueta «Publicado», según el contrato
  de Material. `APPROVED` se conserva para los fixtures visuales existentes.
  El nuevo fixture `gateway_list.json` es sintético, construido con el formato
  de OpenAPI; no se presenta como una captura de datos reales.
- Se corrigió la paginación de #307: una búsqueda, filtro o refresco nuevos
  reinician `isLoadingMore`. Las respuestas antiguas siguen descartándose y
  no pueden apagar la carga de una página nueva. Hay seis pruebas con futuros
  controlados: tres acciones, cada una con éxito o error de la página antigua.
- La pantalla de búsqueda conserva su repositorio mock. Preparar los providers
  del listado HTTP no equivale a integrar Search ni todas las pantallas.

### Validación final

Desde `mobile/`:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter test --dart-define=API_GATEWAY_URL=https://gateway.example.test/api/v1 \
  --dart-define=CATALOG_SERVICE_URL=http://localhost:3002/api/v1 \
  test/core/config/api_config_test.dart \
  test/features/catalog/data/catalog_gateway_provider_test.dart \
  test/features/materials/presentation/material_gateway_provider_test.dart
```

- Formato y análisis sin errores.
- 124 pruebas aprobadas; las 2 pruebas HTTP optativas se omiten en la batería
  normal. Respecto del día 1 hay 6 casos de regresión de paginación, 6 del
  adaptador Material y 4 de sus providers, además de los cambios de `main`.
- Las 11 pruebas de configuración/providers pasan también con un Gateway
  personalizado y el define antiguo de Catalog. Ese define no cambia el destino.

### Conexión real y errores del Gateway

Se compiló el Backend de `8736888` en una copia temporal, sin modificar sus
fuentes. Se levantaron los procesos reales de Gateway, Catalog y Material y
un PostgreSQL 17 temporal, con esquemas independientes para Catalog y Material.
Se prepararon una asignatura, un material `PUBLISHED` y otro `PENDING_REVIEW`.

`test/integration/gateway_live_test.dart` consumió los providers de producción
y Dio real, con `API_GATEWAY_URL` apuntando al Gateway temporal:

- Catalog devolvió la asignatura preparada a través de `/api/v1/catalog`.
- Material devolvió el material publicado, con paginación y estado reconocidos;
  todos los resultados fueron `PUBLISHED`.
- Tras detener solo Catalog y Material, ambas consultas recibieron `502` por
  el mismo Gateway. Catalog conservó el error en el interceptor y Material
  expuso `ApiException` con el código y mensaje del servicio no disponible.
- Resultado: 2 pruebas con servicios disponibles y 2 con servicios caídos,
  todas aprobadas. Los procesos y el PostgreSQL temporal se retiraron después.

Los comandos para repetir ambos escenarios están en
[`mobile/README.md`](../../mobile/README.md#comprobación-http-con-backend-real-opcional).
Las pruebas HTTP solo leen datos. Para verificar registros concretos, proporcionar
`EXPECTED_SUBJECT_ID` y `EXPECTED_MATERIAL_ID` de una base de prueba previamente
preparada. La comprobación real se ejecutó desde macOS; Android/iOS se validaron
en la resolución de configuración mediante pruebas, no ejecutando simuladores.

### Dependencias y control de entrega

#221 sigue abierta (separación definitiva de Catalog/Material/Search). No impide
esta configuración: se verificaron el árbol de Catalog y el listado básico de
Material actualmente publicados. #222 está cerrada y su proxy está integrado.
No se implementaron funcionalidades de Backend ni cambios de contrato para
resolver esas tareas externas.

Los criterios técnicos de #272 quedan cubiertos. No se actualizaron horas,
estado de la issue ni PRs. La entrega se publica, por solicitud del usuario,
en la rama `feature/272-gateway-material-catalog`.
