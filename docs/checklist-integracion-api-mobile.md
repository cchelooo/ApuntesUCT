# Checklist y Matriz Final de Integración API — Mobile (INT4)

**Sprint 2 — Cierre de Integración y Matriz de Estado (Semana 4)** — Registro oficial y seguimiento de endpoints, contratos de datos, validaciones y estado de integración de la aplicación Mobile (INT4) conectada a los microservicios backend a través del API Gateway NestJS.

> **Estado**: Actualizado al cierre del Sprint 2 (Semana 4) conforme a los entregables de Backend (INT2) y Mobile (INT4).
> **Referencia de Tarea**: [Issue #301](https://github.com/cchelooo/ApuntesUCT/issues/301) — Preparar evidencia y matriz final de integración.

---

## 1. Configuración de Red y Conectividad (API Gateway)

La aplicación Mobile **no consume los microservicios directamente**, sino exclusivamente a través del **API Gateway** (puerto `3000`), el cual centraliza el enrutamiento mediante proxy HTTP inverso hacia cada servicio:

| Entorno / Plataforma | URL Base Gateway | Configuración / Resolución |
|---|---|---|
| **Android Emulador** | `http://10.0.2.2:3000/api/v1` | Resuelto automáticamente por `ApiConfig.gatewayBaseUrl` |
| **Dispositivo Android Físico** | `http://<IP_HOST>:3000/api/v1` | Configurable vía `--dart-define=API_GATEWAY_URL=...` |
| **Web / Desktop / Local** | `http://localhost:3000/api/v1` | Valor por defecto en desarrollo de escritorio |
| **Variable de entorno** | Definible en tiempo de build | Prioridad máxima en `mobile/lib/core/config/api_config.dart` |

### Parámetros Globales
- **Prefijo unificado de rutas**: `/api/v1`
- **Headers estándar**:
  - `Content-Type: application/json` (o `multipart/form-data` en subidas binarias)
  - `Authorization: Bearer <accessToken>` (en rutas protegidas)
- **Topología de red verificada**:
  ```
  App Mobile (Android / Flutter)
               │
               ▼
      API Gateway :3000
    ┌──────────┬──────────┬──────────┬──────────┐
    ▼          ▼          ▼          ▼          ▼
  Auth      Catalog    Material    Search    Quality
  :3001      :3002      :3003      :3005     (no enrutado)
                          │
                          ▼
                        MinIO
                        :9000
  ```

---

## 2. Matriz Final de Integración (Sprint 2 — Cierre)

### Leyenda de Estados
- 🟢 **Integrado**: Endpoint enrutado por Gateway, implementado en Backend y consumido en Mobile de forma funcional contra datos reales o backend de pruebas.
- 🟡 **Probado con Mock**: Lógica, modelos y UI completamente implementados en Mobile y validados con mocks/fixtures con contratos idénticos al Swagger, a la espera de despliegue conjunto de Gateway.
- 🔴 **Bloqueado**: Funcionalidad no disponible en Backend (servicio no enrutado, placeholder o sin endpoint publicado) que impide la integración en Mobile durante el Sprint 2.
- ⚪ **Pendiente**: Endpoint planificado para fases posteriores o secundario que no bloquea el flujo principal del sprint.

| Servicio | Método | Ruta Pública (Gateway) | Estado | Evidencia Técnica en Mobile / Repo | Limitaciones / Dependencias Backend |
|---|---|---|:---:|---|---|
| **Auth** | `POST` | `/api/v1/auth/login` | 🟢 **Integrado** | `login_dio_test.dart`, `dio_auth_repository.dart` | Autenticación mock JWT con claim `mock: true`. |
| **Auth** | `POST` | `/api/v1/auth/register` | ⚪ **Pendiente** | `RegisterScreen`, `register_navigation_test.dart` | Devuelve `404 Not Found` en Gateway; backend no expone registro aún. |
| **Auth** | `GET` | `/api/v1/auth/me` | ⚪ **Pendiente** | `profile_screen_test.dart`, `profile_screen.dart` | No publicado en Swagger; Mobile preserva datos del usuario autenticado en login. |
| **Auth** | `POST` | `/api/v1/auth/logout` | ⚪ **Pendiente** | `home_screen_test.dart`, `auth_notifier.dart` | Mobile realiza logout local seguro (limpieza de tokens y estado en Riverpod). |
| **Catalog** | `GET` | `/api/v1/catalog/universities` | 🟡 **Probado con Mock** | `academic_filter_sheet_test.dart`, `academic_hierarchy_provider_test.dart` | Backend implementó #221 en `main`. Mobile maquetó selector con validación de fallback. |
| **Catalog** | `GET` | `/api/v1/catalog/careers` | 🟡 **Probado con Mock** | `academic_filter_sheet_test.dart` (cascada aislada por `universityId`) | Cascada dependiente del padre; validado con fixtures idénticos al contrato. |
| **Catalog** | `GET` | `/api/v1/catalog/subjects` | 🟡 **Probado con Mock** | `academic_filter_sheet_test.dart` (cascada por `careerId`) | Cascada dependiente del padre; validado con fixtures idénticos al contrato. |
| **Catalog** | `GET` | `/api/v1/catalog/professors` | 🟡 **Probado con Mock** | `academic_filter_sheet_test.dart` (profesores por `subjectId`) | Cascada dependiente del padre; validado con fixtures idénticos al contrato. |
| **Catalog** | `GET` | `/api/v1/catalog/filter` | 🟡 **Probado con Mock** | `catalog_screen_test.dart`, `catalog_repository_test.dart` | Endpoint de consulta jerárquica combinada. |
| **Material** | `GET` | `/api/v1/materials` | 🟢 **Integrado** | `materials_discovery_provider.dart`, `gateway_discovery_ui_test.dart` | Listado paginado general con `page` y `pageSize`. |
| **Material** | `POST` | `/api/v1/materials` | 🟢 **Integrado** | `material_upload_screen_test.dart`, `material_upload_live_test.dart` | Subida multipart hasta 15 MB (PDF, Word, PPT) o enlace `LINK`. Retorna `PENDING_REVIEW`. |
| **Material** | `GET` | `/api/v1/materials/:id` | 🟢 **Integrado** | `material_detail_screen_test.dart`, `material_detail_refresh_test.dart` | Detalle estructurado con historial de versiones, metadatos y referencias académicas. |
| **Material** | `GET` | `/api/v1/materials/:id/download` | 🟢 **Integrado** | `material_download_test.dart`, `material_download_native_test.dart` | Descarga binaria con streaming, cabeceras `Content-Disposition` UTF-8 y guardado local. |
| **Material** | `POST` | `/api/v1/materials/:id/versions` | 🟢 **Integrado** | `material_version_history_test.dart`, `material_version_upload_sheet_test.dart` | Subida de versión incremental con `changesDescription` y archivo o enlace. |
| **Material** | `GET` | `/api/v1/materials/:id/preview` | 🔴 **Bloqueado** | — | Endpoint de visualización embebida/streaming no diseñado en Backend para Sprint 2. |
| **Search** | `GET` | `/api/v1/search` | 🟢 **Integrado** | `material_year_type_filter_test.dart`, `material_hierarchy_filter_connection_test.dart`, `material_discovery_search_page_test.dart` | Búsqueda desacoplada por texto (`q`), 6 filtros oficiales (`universityId`, `careerId`, `subjectId`, `professorId`, `year`, `type`), ordenamiento y paginación. |
| **Quality** | `POST` | `/api/v1/quality/ratings` | 🔴 **Bloqueado** | — | Quality Service no enrutado por Gateway ni implementado en Sprint 2 (Sprint 3). |
| **Quality** | `POST` | `/api/v1/quality/favorites` | 🔴 **Bloqueado** | — | No enrutado en Gateway. |
| **Quality** | `DELETE` | `/api/v1/quality/favorites/:id`| 🔴 **Bloqueado** | — | No enrutado en Gateway. |
| **Quality** | `POST` | `/api/v1/quality/reports` | 🔴 **Bloqueado** | — | No enrutado en Gateway. |

---

## 3. Resumen Cuantitativo del Cierre de Sprint 2

```
Total de endpoints evaluados: 20
├── 🟢 Integrados:            7  (35.0%)
├── 🟡 Probados con Mock:     5  (25.0%)
├── 🔴 Bloqueados (Backend):  5  (25.0%)
└── ⚪ Pendientes / Futuros:  3  (15.0%)
```

- **Cobertura del flujo crítico del estudiante**: **100%** de las rutas esenciales para el Sprint 2 (Login -> Exploración -> Subida -> Búsqueda con 6 filtros -> Detalle -> Descarga -> Nueva versión) se encuentran completamente operativas e integradas.
- **Rutas bloqueadas**: Se limitan estrictamente al módulo de Quality (calificaciones, reportes, favoritos) y previsualización embebida, las cuales corresponden por diseño a etapas posteriores del proyecto.

---

## 4. Detalle de Integración por Microservicio

### 4.1. Auth Service (`/api/v1/auth`)
- **Login (`POST /auth/login`)**:
  - Implementado con `DioAuthRepository` utilizando el cliente HTTP centralizado `ApiClient`.
  - Envía `LoginDto` (`email`, `password`) validando formato de correo institucional y rechazando cadenas vacías.
  - Almacena el `accessToken` en memoria y sesión local.
  - Evidencia: `mobile/test/features/auth/presentation/login_dio_test.dart`.
- **Dependencias pendientes**:
  - El backend actualmente opera con token mock JWT sin firma criptográfica (`alg: none`) con claim `mock: true`. La integración con hash bcrypt y PostgreSQL real quedó pospuesta por Backend.
  - Registro de usuarios (`POST /auth/register`) retorna `404 Not Found`; la pantalla `RegisterScreen` cuenta con validaciones completas a nivel cliente listas para conectar.

### 4.2. Material Service (`/api/v1/materials`)
- **Listado Paginado (`GET /materials`)**:
  - Permite recuperar materiales activos sin filtros con parámetros `page` y `pageSize`.
- **Subida de Material (`POST /materials`)**:
  - Envía formulario `multipart/form-data` con archivo binario (máx. 15 MB, formatos permitidos: `.pdf`, `.doc`, `.docx`, `.ppt`, `.pptx`) o enlace externo `externalLink` para tipo `LINK`.
  - Estado inicial devuelto por el servidor: `PENDING_REVIEW`.
  - Evidencia: `mobile/test/features/materials/presentation/material_upload_screen_test.dart` y `mobile/test/integration/material_upload_live_test.dart`.
- **Detalle de Material (`GET /materials/:id`)**:
  - Resuelve metadatos, autor, carrera, asignatura, profesor y el historial completo de versiones publicadas.
  - Evidencia: `mobile/test/features/materials/presentation/material_detail_screen_test.dart`.
- **Descarga de Binarios (`GET /materials/:id/download`)**:
  - Descarga mediante streaming binario conservando cabeceras `Content-Type` y `Content-Disposition` con soporte para nombres UTF-8 (`filename*`).
  - Integración nativa con `open_filex` para visualización en aplicaciones externas del dispositivo.
  - Evidencia: `mobile/test/features/materials/presentation/material_download_test.dart`.
- **Historial y Nuevas Versiones (`POST /materials/:id/versions`)**:
  - Envía nueva versión asociada a un material existente con metadatos de cambios y archivo o enlace.
  - Evidencia: `mobile/test/features/materials/presentation/material_version_history_test.dart`.

### 4.3. Search Service (`/api/v1/search`)
- **Búsqueda Desacoplada y Filtros Jerárquicos (`GET /search`)**:
  - Consume el endpoint unificado `/api/v1/search` enrutado por el Gateway.
  - Soporta los 6 filtros oficiales del Sprint 2:
    1. `universityId` (UUID)
    2. `careerId` (UUID)
    3. `subjectId` (UUID)
    4. `professorId` (UUID)
    5. `year` (Número entero de 4 dígitos: 1900–2099)
    6. `type` (Enum contractual: `DOCUMENT`, `PRESENTATION`, `EXAM`, `SUMMARY`, `LINK`)
  - Soporta ordenamiento por `sortBy` (`createdAt`, `title`, `year`) y `order` (`asc`, `desc`).
  - Maneja respuestas vacías, debounce de 300 ms en entrada de texto y deduplicación en paginación.
  - Evidencia: `mobile/test/features/materials/presentation/material_year_type_filter_test.dart` y `mobile/test/features/materials/presentation/material_hierarchy_filter_connection_test.dart`.

### 4.4. Catalog Service (`/api/v1/catalog`)
- **Selectores Académicos**:
  - Mobile maquetó el modal interactivo `AcademicFilterSheet` que implementa la cascada dependiente: Universidad -> Carrera -> Asignatura -> Profesor -> Año -> Tipo.
  - El reseteo de niveles superiores invalida y limpia automáticamente las selecciones hijas.
  - Evidencia: `mobile/test/features/catalog/presentation/academic_filter_sheet_test.dart` y `mobile/test/features/catalog/presentation/academic_hierarchy_provider_test.dart`.

### 4.5. Quality Service (`/api/v1/quality`)
- **Estado**: Totalmente bloqueado. El Gateway no enruta ninguna ruta de `/api/v1/quality` y el microservicio correspondiente no fue implementado por el equipo de backend para el Sprint 2.

---

## 5. Formato Estándar de Errores y Resiliencia

El Gateway y los microservicios responden bajo la estructura estándar RFC / NestJS:

```json
{
  "statusCode": 400,
  "message": "year debe ser un año válido de 4 dígitos (ej. 2026)",
  "error": "Bad Request"
}
```

En caso de indisponibilidad o fallo de microservicio aguas abajo:
- **`502 Bad Gateway`**: `{ "statusCode": 502, "message": "Search Service no disponible" }`
- **`503 Service Unavailable`**: `{ "statusCode": 503, "message": "Almacenamiento no disponible" }`

En Flutter, `ErrorInterceptor` y `apiErrorMessage(...)` capturan estos códigos y presentan mensajes comprensibles con opciones de reintento (`ErrorState`) sin provocar cierres inesperados de la aplicación.

---

## 6. Seguridad y Protección de Datos

- **Ausencia de secretos**: No se incluyen tokens JWT válidos, contraseñas de producción ni variables privadas en el repositorio.
- **Datos controlados**: Los datos de prueba utilizados en pruebas de integración y ejemplos utilizan correos de formato institucional genérico (`estudiante@alu.uct.cl`) y UUIDs estándar RFC 4122 generados aleatoriamente.
- **Seguridad en almacenamiento local**: Los tokens de sesión se gestionan mediante almacenamiento seguro sin exposición a logs o capturas de pantalla.

---

## 7. Registro de Control y Entrega (#301)

- **Issue**: [#301 Preparar evidencia y matriz final de integración](https://github.com/cchelooo/ApuntesUCT/issues/301)
- **Responsable**: Nelson Quiñinao Isla (Equipo INT4 - Mobile)
- **Evidencia**:
  - Matriz técnica consolidada en este documento (`docs/checklist-integracion-api-mobile.md`).
  - Rama de trabajo: `docs/issue-301-preparar-evidencia-matriz-final-integracion`.
  - Pull Request asociado con referencia de cierre (`closes #301`).
- **Seguimiento de Horas**:
  - Horas asignadas: 2h
  - Horas usadas: 2h
  - Horas restantes: 0h
  - Estado: *Done / Completada*
