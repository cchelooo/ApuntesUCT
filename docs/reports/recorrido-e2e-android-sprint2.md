# Reporte de Recorrido End-to-End en Android — Sprint 2 (#300)

- **Fecha de actualización**: 26 de noviembre de 2026
- **Responsable**: Nelson Quiñinao Isla (Equipo INT4 - Mobile)
- **Tarea**: [#300 Ejecutar recorrido end-to-end manual en Android](https://github.com/cchelooo/ApuntesUCT/issues/300)
- **Sprint**: Sprint 2 — Semana 4 (Cierre de Integración)
- **Referencias**:
  - [Issue #263 — Recorrido Gateway → Material/Search/Catalog](https://github.com/cchelooo/ApuntesUCT/issues/263)
  - [Validación integrada Android/iOS (`validacion-mobile-2026-11-04.md`)](validacion-mobile-2026-11-04.md)
  - [Registro HTTP y artefactos Android (`evidence/mobile-2026-11-04/android/report.json`)](evidence/mobile-2026-11-04/android/report.json)

---

## 1. Entorno Real del Proyecto y Alcance de la Evidencia Disponible

| Parámetro | Valor Real |
|---|---|
| **Aplicación** | ApuntesUCT Mobile (`apuntesuct_mobile`, `mobile/pubspec.yaml`) |
| **Versión en `pubspec.yaml`** | `1.0.0+1` |
| **Framework / SDK** | Flutter `3.47.2` (channel stable) / Dart `3.13.2` (`sdk: ^3.13.2`) |
| **Emulador Android** | `Medium_Phone` (Android 17 / API 37, `arm64`) |
| **Gateway en Android Emulator** | `http://10.0.2.2:<PORT>/api/v1` (por defecto `http://10.0.2.2:3000/api/v1` en `ApiConfig.gatewayBaseUrl`) |
| **Frontera de Red** | Tráfico HTTP dirigido exclusivamente al API Gateway; sin conexión directa desde Mobile a los puertos internos `3001`, `3002`, `3003` o `3005`. |

> **Alcance real de la evidencia Android disponible**:
> La corrida nativa en Android Emulator registrada en `docs/reports/evidence/mobile-2026-11-04/android/` acredita **únicamente seis peticiones HTTP `200`** (Login, Catálogo, Listado, Búsqueda, Detalle y Descarga guardada en caché nativa).
> **Subida desde la interfaz, versionado desde `MaterialVersionUploadSheet`, apertura en visor externo (`OpenFilex.open`) y pruebas manuales de errores (`502`/`503` y validación de archivos) NO tienen evidencia capturada en esa ejecución Android.** Las pruebas de widgets o de transporte simulado en `mobile/test/` verifican comportamiento del código Dart, pero **no reemplazan ni acreditan la ejecución manual en Android**.

---

## 2. Matriz de Estado del Recorrido Android (Evidencia Nativa vs. Pendiente)

| # | Paso del Recorrido (#300) | Estado en Android Real | Solicitud HTTP en Android | Evidencia Nativa en Repositorio | Observación / Límite Real |
|---|---|:---:|---|---|---|
| **1** | Iniciar sesión mediante Gateway | ✅ **Acreditado en Android** | `POST /api/v1/auth/login` → `200` | [`android/login.png`](evidence/mobile-2026-11-04/android/login.png), [`android/report.json`](evidence/mobile-2026-11-04/android/report.json) | Navega a Inicio. En el cierre de Sprint 2 el backend emitía JWT simulado (`mock: true`). |
| **2** | Cargar catálogo académico | ✅ **Acreditado en Android** | `GET /api/v1/catalog` → `200` | [`android/catalogo.png`](evidence/mobile-2026-11-04/android/catalogo.png), [`android/report.json`](evidence/mobile-2026-11-04/android/report.json) | Verifica carga del árbol general `/api/v1/catalog` con la asignatura `Asignatura QA278`. Los selectores en cascada (`/universities`, `/careers`, `/subjects`, `/professors`) no fueron capturados en la corrida nativa. |
| **3** | Seleccionar archivo y completar clasificación en UI | ⚠️ **Sin evidencia Android nativa** | — | *Pendiente de captura manual en emulador* | El fixture de la corrida `mobile-2026-11-04` fue preparado por el script `start_gateway_smoke.cjs`, no desde `MaterialUploadScreen` en Android. |
| **4** | Subir material desde UI y confirmar `PENDING_REVIEW` | ⚠️ **Sin evidencia Android nativa** | `POST /api/v1/materials` (ejecutado por script de preparación, no desde UI Android) | *Pendiente de captura manual en emulador* | El script de preparación envió `POST /materials` recibiendo `201` y `PENDING_REVIEW`, pero falta la captura y traza de subida iniciada desde el formulario Mobile en Android. |
| **5** | Listar y buscar material publicado | ✅ **Acreditado en Android** | `GET /api/v1/materials?page=1&pageSize=5` → `200`<br>`GET /api/v1/search?q=Integracion278&page=1&pageSize=5` → `200` | [`android/listado.png`](evidence/mobile-2026-11-04/android/listado.png), [`android/busqueda.png`](evidence/mobile-2026-11-04/android/busqueda.png), [`android/report.json`](evidence/mobile-2026-11-04/android/report.json) | Material `a7f01fd8-c769-4b86-a89b-c258ebd27d79` (`Integracion278`) listado y encontrado por texto contra Gateway real. |
| **6** | Abrir detalle de material | ✅ **Acreditado en Android** | `GET /api/v1/materials/a7f01fd8-c769-4b86-a89b-c258ebd27d79` → `200` | [`android/detalle.png`](evidence/mobile-2026-11-04/android/detalle.png), [`android/report.json`](evidence/mobile-2026-11-04/android/report.json) | Navegación desde tarjeta al detalle mostrando metadatos y versión actual `v1`. |
| **7a** | Descargar binario y guardar en caché nativa | ✅ **Acreditado en Android** | `GET /api/v1/materials/a7f01fd8-c769-4b86-a89b-c258ebd27d79/download?versionId=7f6ff347-513f-4fa5-9514-b610ab0e1a28` → `200` | [`android/descarga.png`](evidence/mobile-2026-11-04/android/descarga.png), [`android/report.json`](evidence/mobile-2026-11-04/android/report.json) | PDF de `414` bytes guardado en caché nativa (`SHA-256: a2b4945b6565b105cbf8ab4dc1d86bfc925d1e3eaa91cfb6ea770d292c333d28`). |
| **7b** | Abrir archivo descargado en visor externo | ⚠️ **Sin evidencia Android nativa** | — | *Pendiente de captura manual en emulador* | La corrida nativa verifica la descarga y guardado en caché, pero no invoca `OpenFilex.open` ni captura un visor PDF externo de Android. |
| **8** | Crear nueva versión desde `MaterialVersionUploadSheet` | ⚠️ **Sin evidencia Android nativa** | — | *Pendiente de captura manual en emulador* | No ejecutado en la corrida nativa de Android. |
| **9** | Servicio caído (`502`/`503`) y errores de validación de archivo (`> 15 MB` / formato inválido) | ⚠️ **Sin evidencia Android nativa** | — | *Pendiente de captura manual en emulador* | Cubierto solo por pruebas automatizadas de cliente; falta evidencia de ejecución manual en Android Emulator. |

---

## 3. Detalle de las Seis Operaciones Acreditadas en Android (`mobile-2026-11-04`)

Los datos verificables de la corrida ejecutada en Android Emulator (`10.0.2.2:50461`) registrada en [`docs/reports/evidence/mobile-2026-11-04/android/report.json`](evidence/mobile-2026-11-04/android/report.json) son:

- **APK Debug compilado**: `mobile/build/app/outputs/flutter-apk/app-debug.apk` (`173.327.105` bytes, `SHA-256: a666044cba0ec10ba4d4b3ddeb4911a4f16b3e25f7b92b2cd3ae89d6a19070db`), con captura de arranque en [`arranque-android.png`](evidence/mobile-2026-11-04/arranque-android.png).
- **Fixture en PostgreSQL y MinIO reales**:
  - `materialId`: `a7f01fd8-c769-4b86-a89b-c258ebd27d79`
  - `versionId`: `7f6ff347-513f-4fa5-9514-b610ab0e1a28`
  - `title`: `Integracion278`
  - `subjectName`: `Asignatura QA278`
  - `pdfBytes`: `414` (`SHA-256: a2b4945b6565b105cbf8ab4dc1d86bfc925d1e3eaa91cfb6ea770d292c333d28`)
- **Secuencia de 6 peticiones HTTP confirmadas**:
  1. `POST /api/v1/auth/login` → `200` ([`android/login.png`](evidence/mobile-2026-11-04/android/login.png))
  2. `GET /api/v1/catalog` → `200` ([`android/catalogo.png`](evidence/mobile-2026-11-04/android/catalogo.png))
  3. `GET /api/v1/materials?page=1&pageSize=5` → `200` ([`android/listado.png`](evidence/mobile-2026-11-04/android/listado.png))
  4. `GET /api/v1/search?q=Integracion278&page=1&pageSize=5` → `200` ([`android/busqueda.png`](evidence/mobile-2026-11-04/android/busqueda.png))
  5. `GET /api/v1/materials/a7f01fd8-c769-4b86-a89b-c258ebd27d79` → `200` ([`android/detalle.png`](evidence/mobile-2026-11-04/android/detalle.png))
  6. `GET /api/v1/materials/a7f01fd8-c769-4b86-a89b-c258ebd27d79/download?versionId=7f6ff347-513f-4fa5-9514-b610ab0e1a28` → `200` ([`android/descarga.png`](evidence/mobile-2026-11-04/android/descarga.png))

---

## 4. Comportamiento Real en Código de los Pasos Pendientes de Evidencia Manual en Android

Para los pasos que aún no cuentan con captura en el emulador Android, se documenta el comportamiento real implementado en `mobile/lib/` (sin presentar sus pruebas de widgets como evidencia de ejecución manual):

1. **Subida de material (`MaterialUploadScreen`, `/materials/upload`)**:
   - Carga selectores jerárquicos (`/catalog/universities`, `/careers`, `/subjects`, `/professors`), valida localmente extensión (`.pdf`, `.doc`, `.docx`, `.ppt`, `.pptx`) y límite de `15 MB` (`MaterialUploadValidation.validatePickedFile`), y envía `POST /api/v1/materials`.
   - Al recibir `201 Created`, presenta el material con estado `PENDING_REVIEW` (`Pendiente de revisión`).
2. **Creación de nueva versión (`MaterialVersionUploadSheet`)**:
   - Admite exclusivamente un archivo binario local (`file`); **no posee campo `changesDescription` ni acepta enlaces externos**.
   - Envía `POST /api/v1/materials/:id/versions`.
   - Tras recibir `201 Created`, **el modal NO se cierra automáticamente**: permanece abierto mostrando `_SuccessBody` (*"Versión v<N+1> creada"*, *"“<archivo>” ya está disponible como v<N+1>. La versión anterior sigue en el historial."*) con los botones explícitos **"Cerrar"** (`Navigator.of(context).pop()`) y **"Subir otra versión"**, e invalida `materialDetailProvider(materialId)` / `materialDetailByIdProvider(materialId)`.
3. **Apertura externa (`MaterialDownloadActions` / `MaterialVersionHistory`)**:
   - Una vez guardado el archivo en el directorio temporal (`NativeMaterialFileHandler.save`), el botón *"Abrir"* invoca `OpenFilex.open(savedFile.path, type: mimeType)`.
4. **Manejo de errores (`502`/`503` y validación de archivo)**:
   - `ErrorInterceptor` mapea respuestas `502`/`503` a `ApiException`; las vistas muestran `ErrorState` con acción *"Reintentar"* o `FormErrorBanner` conservando los datos del formulario.

---

## 5. Discrepancias y Limitaciones Registradas Respecto del E2E de Backend (#263)

| Aspecto | Backend (#263) | Mobile (Android) | Estado |
|---|---|---|---|
| **Resolución de host** | `http://localhost:3000/api/v1` | `http://10.0.2.2:<PORT>/api/v1` | Resuelto en `ApiConfig.gatewayBaseUrl`. |
| **Cobertura del recorrido nativo** | El test E2E de Backend ejecuta creación, publicación en BD, búsqueda, detalle, versionado y descarga por HTTP. | La corrida nativa Android (`mobile-2026-11-04`) ejecuta las 6 peticiones de lectura/login/descarga; subida, versionado, apertura externa y errores desde UI Android permanecen pendientes de captura manual completa. | Limitación explícita registrada para coordinación con QA de Sprint 3. |
| **Visibilidad pública tras subida** | `POST /materials` crea el material en `PENDING_REVIEW`; listado y búsqueda pública solo exponen `PUBLISHED`. | Un material recién subido desde Mobile permanece en `PENDING_REVIEW` y no aparece en `/materials` ni `/search` hasta ser aprobado/publicado. | Coherente con el contrato de visibilidad. |
| **Codificación de nombre de archivo con tilde** | `Guía278.pdf` se registró como `GuÃ­a278.pdf` en los metadatos devueltos por el servicio durante la corrida `#278`. | Los bytes descargados en Android conservan integridad exacta (`SHA-256` idéntico al fixture original). | Documentado en `validacion-mobile-2026-11-04.md`. |
