# Reporte de Recorrido End-to-End Manual en Android — Sprint 2

- **Fecha de actualización**: 15 de noviembre de 2026
- **Responsable**: Nelson Quiñinao Isla (Equipo INT4 - Mobile)
- **Tarea**: [#300 Ejecutar recorrido end-to-end manual en Android](https://github.com/cchelooo/ApuntesUCT/issues/300)
- **Sprint**: Sprint 2 — Semana 4 (Cierre de Integración)
- **Referencias**:
  - [Issue #263 — Recorrido Gateway → Material/Search/Catalog](https://github.com/cchelooo/ApuntesUCT/issues/263)
  - [Validación integrada Android/iOS (`validacion-mobile-2026-11-04.md`)](validacion-mobile-2026-11-04.md)

---

## 1. Entorno de Ejecución y Versión Real de la Aplicación

| Parámetro | Valor Real Registrado |
|---|---|
| **Aplicación** | ApuntesUCT Mobile (`apuntesuct_mobile`, `mobile/pubspec.yaml`) |
| **Versión en `pubspec.yaml`** | `1.0.0+1` |
| **Framework / SDK** | Flutter `3.47.2` (channel stable) / Dart `3.13.2` (`sdk: ^3.13.2`) |
| **DevTools** | `2.60.0` |
| **Entorno Android** | Android Emulator (`Medium_Phone` / Pixel, host resuelto vía `10.0.2.2`) |
| **Punto de Entrada HTTP** | `http://10.0.2.2:3000/api/v1` por defecto en `ApiConfig.gatewayBaseUrl` (o `http://10.0.2.2:<PORT>/api/v1` mediante `--dart-define=API_GATEWAY_URL=...`) |
| **Regla de Aislamiento** | **Ninguna llamada de Mobile se realiza a puertos internos de microservicios** (`3001`, `3002`, `3003`, `3005`). Todo el tráfico pasa por el API Gateway. |

---

## 2. Reproducibilidad y Evidencia Verificable

El recorrido es reproducible mediante dos mecanismos complementarios presentes en el repositorio:

### 2.1. Ejecución en Emulador Android contra Gateway y Servicios Reales
1. Levantar la pila local (PostgreSQL, MinIO, Auth, Catalog, Material, Search y API Gateway) o ejecutar el arnés reproducible:
   ```bash
   cd mobile
   flutter pub get
   flutter analyze
   ```
2. Para ejecutar el recorrido instrumentado en Android Emulator con capturas y trazas HTTP reales (documentado en `docs/reports/validacion-mobile-2026-11-04.md`):
   - Evidencia gráfica Android generada en el repositorio:
     - Arranque APK debug: [`docs/reports/evidence/mobile-2026-11-04/arranque-android.png`](evidence/mobile-2026-11-04/arranque-android.png)
     - Login: [`docs/reports/evidence/mobile-2026-11-04/android/login.png`](evidence/mobile-2026-11-04/android/login.png)
     - Catálogo: [`docs/reports/evidence/mobile-2026-11-04/android/catalogo.png`](evidence/mobile-2026-11-04/android/catalogo.png)
     - Listado de materiales: [`docs/reports/evidence/mobile-2026-11-04/android/listado.png`](evidence/mobile-2026-11-04/android/listado.png)
     - Búsqueda: [`docs/reports/evidence/mobile-2026-11-04/android/busqueda.png`](evidence/mobile-2026-11-04/android/busqueda.png)
     - Detalle de material: [`docs/reports/evidence/mobile-2026-11-04/android/detalle.png`](evidence/mobile-2026-11-04/android/detalle.png)
     - Descarga guardada: [`docs/reports/evidence/mobile-2026-11-04/android/descarga.png`](evidence/mobile-2026-11-04/android/descarga.png)
     - Registro estructurado de peticiones HTTP y hashes: [`docs/reports/evidence/mobile-2026-11-04/android/report.json`](evidence/mobile-2026-11-04/android/report.json)

### 2.2. Verificación Reproducible de Flujos de Subida, Versionado, Filtros y Errores
Los pasos de formulario de subida, creación de nueva versión, validación de archivos y manejo de errores HTTP se reproducen de forma determinista con:
```bash
cd mobile
flutter test \
  test/features/auth/presentation/login_dio_test.dart \
  test/features/catalog/presentation/academic_filter_sheet_test.dart \
  test/features/materials/presentation/material_upload_screen_test.dart \
  test/features/materials/presentation/material_upload_visible_behavior_test.dart \
  test/features/materials/presentation/material_detail_dio_test.dart \
  test/features/materials/presentation/material_download_test.dart \
  test/features/materials/presentation/material_version_upload_sheet_test.dart \
  test/features/materials/presentation/material_version_visible_behavior_test.dart
```

---

## 3. Recorrido Paso a Paso y Comportamiento Real

### Paso 1: Iniciar sesión mediante Gateway
- **Acción en UI**: En `LoginScreen` (`/login`), se ingresa un correo institucional válido (`estudiante@uct.cl` / `estudiante@alu.uct.cl`) y contraseña no vacía, y se pulsa *"Iniciar Sesión"*.
- **Solicitud HTTP**: `POST /api/v1/auth/login` con cuerpo `{"email": "...", "password": "..."}`.
- **Respuesta del Gateway**: `200 OK` con `accessToken` (JWT mock con claim `mock: true` en el estado del cierre de Sprint 2) y objeto `user`.
- **Comportamiento real en Mobile**:
  - `DioAuthRepository` valida que la respuesta contenga `accessToken` no vacío y el mapa `user`.
  - `AuthStateNotifier` almacena el `UserModel` en memoria dentro de Riverpod (actualmente no persiste el token en almacenamiento seguro del dispositivo).
  - La aplicación navega a la ruta `/` (`HomeScreen`).
- **Evidencia**: [`android/login.png`](evidence/mobile-2026-11-04/android/login.png), `mobile/test/features/auth/presentation/login_dio_test.dart`.

---

### Paso 2: Cargar catálogo y selectores académicos
- **Acción en UI**:
  - Navegación a `/catalog` (`CatalogScreen`) para consultar la jerarquía general (`GET /api/v1/catalog`).
  - Apertura de selectores académicos en `MaterialUploadScreen` o `AcademicFilterSheet`.
- **Solicitudes HTTP consumidas por `DioCatalogSelectorRepository` / `GatewayAcademicHierarchyRepository`**:
  - `GET /api/v1/catalog/universities`
  - `GET /api/v1/catalog/careers?universityId=<uuid>`
  - `GET /api/v1/catalog/subjects?careerId=<uuid>`
  - `GET /api/v1/catalog/professors?subjectId=<uuid>`
- **Comportamiento real en Mobile**:
  - Los niveles hijos permanecen deshabilitados hasta seleccionar el nivel padre.
  - Al cambiar un nivel padre (universidad, carrera o asignatura), las selecciones dependientes inferiores se limpian automáticamente y las peticiones obsoletas en vuelo se descartan para evitar condiciones de carrera.
- **Evidencia**: [`android/catalogo.png`](evidence/mobile-2026-11-04/android/catalogo.png), `mobile/test/features/catalog/presentation/academic_filter_sheet_test.dart`.

---

### Paso 3: Seleccionar archivo y completar clasificación
- **Acción en UI**: En `MaterialUploadScreen` (`/materials/upload`), se completan:
  - Título (`title`) y descripción opcional (`description`).
  - Tipo de material (`type`: `DOCUMENT`, `PRESENTATION`, `EXAM`, `SUMMARY` o `LINK`).
  - Año académico (`academicYear`, entero de 4 dígitos entre 1900 y 2100).
  - Clasificación jerárquica: Universidad, Carrera, Asignatura y Profesor opcional.
  - Archivo local mediante selector (`pickMaterialFile`) para tipos con archivo, o URL (`externalUrl`) cuando el tipo es `LINK`.
- **Validaciones locales ejecutadas (`MaterialUploadValidation`)**:
  - Verifica extensión permitida (`.pdf`, `.doc`, `.docx`, `.ppt`, `.pptx`) y tamaño máximo de **15 MB** (`15 * 1024 * 1024` bytes) antes de enviar.
  - Muestra nombre de archivo y tamaño formateado (`MaterialUploadValidation.formatBytes`).
- **Evidencia**: `mobile/test/features/materials/presentation/material_upload_classification_test.dart`, `mobile/test/features/materials/presentation/material_upload_screen_test.dart`.

---

### Paso 4: Subir material y confirmar `PENDING_REVIEW`
- **Acción en UI**: Se pulsa el botón de envío en `MaterialUploadScreen`.
- **Solicitud HTTP**: `POST /api/v1/materials` (`multipart/form-data` para archivo binario o JSON/form según `DioMaterialRepository.uploadMaterial`).
- **Respuesta del Gateway**: `201 Created` devolviendo el material creado con `status: "PENDING_REVIEW"`.
- **Comportamiento real en Mobile**:
  - El botón de subida se deshabilita mientras `isUploading` es `true` e informa el progreso.
  - Al recibir `201`, la pantalla muestra el estado del material recién creado incluyendo su insignia `Pendiente de revisión` (`PENDING_REVIEW`) sin asumir publicación inmediata.
- **Evidencia**: `mobile/test/features/materials/presentation/material_upload_visible_behavior_test.dart`, `mobile/test/integration/material_upload_live_test.dart`.

---

### Paso 5: Buscar y filtrar un material publicado de prueba
- **Acción en UI**: En `MaterialDiscoveryScreen` (`/materials`), se consulta el listado inicial (`GET /api/v1/materials?page=1&pageSize=5`) y se ejecuta una búsqueda con texto o filtros.
- **Solicitud HTTP**:
  - `GET /api/v1/search?q=<texto>&universityId=...&careerId=...&subjectId=...&professorId=...&year=...&type=...&page=1&pageSize=10`
- **Comportamiento real en Mobile**:
  - La barra de búsqueda aplica debounce de 300 ms antes de invocar a `DioSearchRepository`.
  - Los filtros activos se muestran como `InputChip` individuales junto con la acción *"Limpiar filtros"*.
  - Los resultados se renderizan en tarjetas `MaterialSummaryCard`.
- **Evidencia**: [`android/listado.png`](evidence/mobile-2026-11-04/android/listado.png), [`android/busqueda.png`](evidence/mobile-2026-11-04/android/busqueda.png).

---

### Paso 6: Abrir detalle de material
- **Acción en UI**: Al pulsar una tarjeta `MaterialSummaryCard`, se navega a `/materials/:id` (`MaterialDetailRoute` → `MaterialDetailScreen`).
- **Solicitud HTTP**: `GET /api/v1/materials/:id`
- **Comportamiento real en Mobile**:
  - Muestra título, descripción, clasificación académica, estado (`MaterialStatus`), versión actual (`currentVersion`) e historial completo de versiones (`MaterialVersionHistory`) ordenado de forma descendente por `versionNumber`.
- **Evidencia**: [`android/detalle.png`](evidence/mobile-2026-11-04/android/detalle.png), `mobile/test/features/materials/presentation/material_detail_dio_test.dart`.

---

### Paso 7: Descargar y guardar archivo binario
- **Acción en UI**: En `MaterialDetailScreen` (`MaterialDownloadActions` o fila de versión en `MaterialVersionHistory`), se pulsa *"Descargar"*.
- **Solicitud HTTP**:
  - Descarga principal: `GET /api/v1/materials/:id/download`
  - Descarga de versión específica: `GET /api/v1/materials/:id/download?versionId=<versionId>`
- **Comportamiento real en Mobile**:
  - `DioMaterialRepository.downloadMaterial` recibe los bytes con `ResponseType.bytes` y extrae `fileName` desde `Content-Disposition` (soportando `filename*` UTF-8).
  - `NativeMaterialFileHandler.save` guarda el archivo en el directorio temporal de la aplicación (`getTemporaryDirectory()/apuntesuct_materials/...`).
  - Una vez descargado, habilita la acción *"Abrir"*, la cual invoca `OpenFilex.open(savedFile.path, type: mimeType)` para delegar la apertura al visor nativo del sistema Android.
- **Evidencia**: [`android/descarga.png`](evidence/mobile-2026-11-04/android/descarga.png), `mobile/test/features/materials/presentation/material_download_test.dart`.

---

### Paso 8: Crear una nueva versión de un material existente
- **Acción en UI**: En `MaterialDetailScreen`, se pulsa *"Subir nueva versión"*, abriendo la hoja modal inferior `MaterialVersionUploadSheet`.
- **Comportamiento real de `MaterialVersionUploadSheet`**:
  - Muestra el texto informativo: *"La versión anterior no se elimina: quedará disponible en el historial. Se creará la versión v<N+1>."*
  - **No incluye campo `changesDescription` ni acepta enlaces externos**: el contrato de versionado admite únicamente un archivo binario local (`file`).
  - Se pulsa *"Seleccionar archivo (PDF, Word, PPT · máx. 15 MB)"*. Tras elegir un archivo válido, se muestra en una tarjeta con su nombre, tamaño formateado y botón para quitarlo.
  - Se pulsa *"Confirmar subida de v<N+1>"*, enviando `POST /api/v1/materials/:id/versions` (`multipart/form-data` con campo `file`).
  - Durante el envío se muestra `LinearProgressIndicator` con porcentaje y botón *"Cancelar subida"*.
  - **Al completarse (`201 Created`), el modal NO se cierra automáticamente**: renderiza en la misma hoja la vista de confirmación (`_SuccessBody`) con el título *"Versión v<N+1> creada"*, el mensaje *"“<archivo>” ya está disponible como v<N+1>. La versión anterior sigue en el historial."* y dos acciones explícitas: **"Cerrar"** (que cierra el modal mediante `Navigator.of(context).pop()`) y **"Subir otra versión"**.
  - Paralelamente, `MaterialVersionUploadNotifier` invalida `materialDetailProvider(materialId)`, actualizando el detalle y el historial de versiones en segundo plano.
- **Evidencia**: `mobile/test/features/materials/presentation/material_version_upload_sheet_test.dart`, `mobile/test/features/materials/presentation/material_version_visible_behavior_test.dart`.

---

### Paso 9: Probar servicio caído y errores de validación de archivo

#### 9.1. Servicio caído o error de Gateway (`502` / `503`)
- **Comportamiento real en Mobile**: `ErrorInterceptor` convierte el `DioException` en `ApiException` conservando el `statusCode` y el mensaje del Gateway. Las pantallas (`MaterialDiscoveryScreen`, `MaterialDetailScreen`) renderizan `ErrorState` con opción de *"Reintentar"*, y los formularios (`MaterialUploadScreen`, `MaterialVersionUploadSheet`) muestran `FormErrorBanner` conservando la selección del usuario para reintentar sin perder datos.

#### 9.2. Archivo que supera 15 MB o formato no permitido
- **Comportamiento real en Mobile**: `MaterialUploadValidation.validatePickedFile` valida síncronamente extensión (`.pdf`, `.doc`, `.docx`, `.ppt`, `.pptx`) y tamaño (`<= 15 MB`). Si el archivo excede 15 MB o tiene otra extensión, muestra el error con ícono y texto junto al selector y mantiene deshabilitado el botón de confirmación sin realizar llamadas HTTP.

---

## 4. Discrepancias y Límites Observados Respecto del E2E de Backend (#263)

| Aspecto | Backend (#263) | Mobile (Android) | Estado / Observación |
|---|---|---|---|
| **Host del Gateway** | `http://localhost:3000` | `http://10.0.2.2:3000` | Android Emulator resuelve el loopback del host mediante `10.0.2.2` en `ApiConfig`. |
| **Autenticación en Sprint 2** | `POST /auth/login` emite JWT mock (`alg: none`, `mock: true`). | Valida respuesta HTTP y guarda `UserModel` en memoria (Riverpod); no persiste tokens en almacenamiento seguro ni envía `Authorization` desde `ApiClient` en Sprint 2. | Documentado como límite real del cierre de Sprint 2. |
| **Visibilidad de materiales recién subidos** | `POST /materials` crea el registro en `PENDING_REVIEW`; listado/búsqueda pública solo devuelve `PUBLISHED`. | Mobile confirma `PENDING_REVIEW` al subir; para listar/buscar/descargar en pruebas integradas contra BD real se requiere un material en estado `PUBLISHED`. | Coherente con la frontera pública del contrato. |
| **Codificación de nombres con tilde** | En el smoke test integrado (#278), `Guía278.pdf` se observó como `GuÃ­a278.pdf` en metadatos del servicio. | La descarga binaria conserva los bytes íntegros (`SHA-256` verificado). | Registrado en `validacion-mobile-2026-11-04.md`. |
