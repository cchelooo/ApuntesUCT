# Checklist de Integración API — Mobile (INT4)

**Sprint 1 · Actualización de Integración con Auth y Catálogo** — Registro y seguimiento de endpoints, contratos de datos, validaciones y estado de integración requeridos por la aplicación Mobile (INT4) para conectarse a los microservicios backend a través del API Gateway NestJS.

> **Estado**: Actualizado con el estado real del backend (INT2) a partir de los PRs #76, #91, #92, #97 y los requerimientos de pantallas maquetadas en Mobile (Login, Register, Catálogo, Perfil).

---

## 1. Configuración de Red y Conectividad (API Gateway)

La aplicación Mobile no consume los microservicios directamente, sino a través del **API Gateway** (puerto `3000`), el cual centraliza el enrutamiento mediante proxy HTTP inverso:

| Entorno / Plataforma | URL Base Gateway | Parámetro / Configuración |
|---|---|---|
| **Android Emulador** | `http://10.0.2.2:3000/api/v1` | Resuelto automáticamente por `ApiConfig.gatewayBaseUrl` |
| **Web / Desktop / Local** | `http://localhost:3000/api/v1` | Valor por defecto en desarrollo local |
| **Variable de entorno** | Configurable vía `--dart-define=API_GATEWAY_URL=...` | Prioridad máxima en `mobile/lib/core/config/api_config.dart` |

- **Prefijo global**: `/api/v1`
- **Headers obligatorios**:
  - `Content-Type: application/json`
  - `Authorization: Bearer <accessToken>` (en rutas protegidas)
- **Documentación Swagger activa**:
  - Gateway: `http://localhost:3000/api/docs`
  - Auth Service: `http://localhost:3001/api/docs` (JSON spec en `/api/docs-json`)
  - Catalog Service: `http://localhost:3002/api/docs` (JSON spec en `/api/docs-json`)

---

## 2. Endpoints Requeridos: Auth Service (`/api/v1/auth`)

Microservicio responsable de autenticación, emisión de tokens y gestión de usuarios. Enrutado por el Gateway mediante proxy hacia el puerto `3001` (#91).

### 2.1. `POST /auth/login` — Autenticación de Usuario
- **Estado Backend**:  **Implementado como Mock JWT** (#92).
- **Estado Mobile**:  Listo para consumir con `ApiClient` y `UserModel`.
- **Propósito**: Permitir al estudiante/docente iniciar sesión en la app móvil.
- **Request Body (`LoginDto`)**:
  ```json
  {
    "email": "estudiante@alu.uct.cl",
    "password": "miPasswordSegura123"
  }
  ```
- **Validaciones clave**:
  - `email`: Debe ser un correo con formato válido.
  - `password`: No puede estar vacía ni compuesta únicamente por espacios en blanco (400 Bad Request, #92).
- **Respuesta esperada (`200 OK`)**:
  ```json
  {
    "accessToken": "eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0....",
    "tokenType": "Bearer",
    "expiresIn": 3600,
    "user": {
      "id": "00000000-0000-4000-8000-000000000092",
      "name": "Estudiante de prueba",
      "email": "estudiante@alu.uct.cl",
      "role": "STUDENT",
      "active": true
    }
  }
  ```
- **Notas de integración**:
  - El token mock actual no tiene firma (`alg: none`) y contiene el claim `mock: true`. Sirve para persistir sesión localmente y probar la navegación en Flutter.
  - *Pendiente Backend*: Sustituir mock por autenticación real con hash bcrypt en PostgreSQL y JWT firmado.

---

### 2.2. `POST /auth/register` — Registro de Nuevos Usuarios
- **Estado Backend**: ⏳ **Pendiente** (devuelve `404 Not Found` en el Gateway).
- **Estado Mobile**:  Formulario y validaciones maquetadas en `RegisterScreen`.
- **Propósito**: Crear cuentas de nuevos estudiantes en la plataforma.
- **Request Body requerido por Mobile (`RegisterDto`)**:
  ```json
  {
    "name": "Nelson Quiñinao",
    "email": "nquininao2023@alu.uct.cl",
    "password": "PasswordSegura123!"
  }
  ```
- **Validaciones clave (RF-01, RN-U01)**:
  - Dominio de correo restringido estrictamente a `@uct.cl` o `@alu.uct.cl`.
  - Normalización en backend (trim y conversión a minúsculas antes de persistir).
  - Rol asignado automáticamente como `STUDENT`.
  - Contraseña con requisitos de seguridad mínimos.
- **Respuesta esperada (`201 Created`)**:
  ```json
  {
    "user": {
      "id": "b3c8f1e0-7d42-4b2a-89a1-2d7c1a9e8f43",
      "name": "Nelson Quiñinao",
      "email": "nquininao2023@alu.uct.cl",
      "role": "STUDENT",
      "active": true,
      "createdAt": "2026-09-20T18:00:00.000Z"
    },
    "accessToken": "eyJhbGci...",
    "tokenType": "Bearer",
    "expiresIn": 3600
  }
  ```
  *(Opcionalmente devolver sesión directa para no obligar a un segundo paso de login).*

---

### 2.3. `GET /auth/me` (o `/auth/profile`) — Datos de Perfil del Usuario
- **Estado Backend**: ⏳ **Pendiente**.
- **Estado Mobile**:  Pantalla de Perfil maquetada (#57) esperando endpoint para sincronizar datos en vivo.
- **Propósito**: Obtener la información del usuario autenticado a partir de su Bearer token para mostrar en la cabecera del perfil, estadísticas y ajustes.
- **Headers**: `Authorization: Bearer <accessToken>`.
- **Respuesta esperada (`200 OK`)**:
  ```json
  {
    "id": "b3c8f1e0-7d42-4b2a-89a1-2d7c1a9e8f43",
    "name": "Nelson Quiñinao",
    "email": "nquininao2023@alu.uct.cl",
    "role": "STUDENT",
    "active": true,
    "createdAt": "2026-09-10T14:30:00.000Z"
  }
  ```

---

### 2.4. `POST /auth/logout` — Cierre de Sesión
- **Estado Backend**: ⏳ **Pendiente**.
- **Estado Mobile**:  Limpia estado local (Riverpod / Secure Storage); requiere confirmación en backend para invalidar refresh token.
- **Headers**: `Authorization: Bearer <accessToken>`.
- **Respuesta esperada (`200 OK` / `204 No Content`)**.

---

### 2.5. `POST /auth/refresh` — Renovación de Token de Acceso
- **Estado Backend**: ⏳ **Pendiente** (el modelo Prisma ya contempla `RefreshToken`).
- **Estado Mobile**:  Interceptor preparado para renovación transparente ante error `401 Unauthorized`.
- **Request Body**:
  ```json
  {
    "refreshToken": "string"
  }
  ```
- **Respuesta esperada (`200 OK`)**:
  ```json
  {
    "accessToken": "nuevo_jwt_aqui",
    "tokenType": "Bearer",
    "expiresIn": 3600
  }
  ```

---

## 3. Endpoints Requeridos: Catalog Service (`/api/v1/catalog`)

Microservicio encargado de la estructura académica: Universidades, Carreras, Asignaturas, Profesores y Ofertas Académicas. Expuesto en puerto `3002` (#76, #97).

### 3.1. `GET /catalog/filter` — Búsqueda y Filtrado Jerárquico
- **Estado Backend**:  **Implementado** (#71, #74, #97).
- **Estado Mobile**:  Listo para consumir en `CatalogScreen` y barra de búsqueda.
- **Propósito**: Obtener asignaturas filtradas por jerarquía académica con sus relaciones pre-cargadas.
- **Query Parameters (`FilterCatalogDto`)**:
  - `universityId` (UUID, opcional)
  - `careerId` (UUID, opcional — requiere `universityId`)
  - `subjectId` (UUID, opcional — requiere `careerId`)
  - `professorId` (UUID, opcional — requiere `subjectId`)
  - `year` (Int `2000-2100`, opcional — requiere `professorId`, actualmente *501 Not Implemented*)
  - `type` (String, opcional — requiere `year`, actualmente *501 Not Implemented*)
- **Comportamiento**:
  - Sin parámetros: Devuelve todas las asignaturas.
  - Con filtros válidos: Devuelve asignaturas coincidentes con sus relaciones (`career`, `university`, `professors`).
  - Combinación no existente: Retorna arreglo vacío `[]`.
  - Salto de secuencia obligatoria: Retorna `400 Bad Request`.
- **Respuesta esperada (`200 OK`)**:
  ```json
  [
    {
      "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "name": "Ingeniería de Software",
      "code": "INF-310",
      "career": {
        "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
        "name": "Ingeniería Civil en Informática",
        "university": {
          "id": "f0e1d2c3-b4a5-6789-0123-456789abcdef",
          "name": "Universidad Católica de Temuco",
          "acronym": "UCT"
        }
      },
      "professors": [
        {
          "id": "11223344-5566-7788-99aa-bbccddeeff00",
          "name": "Profesor Ejemplo",
          "email": "profesor@uct.cl"
        }
      ]
    }
  ]
  ```

---

### 3.2. Endpoints REST Individuales Requeridos para Selectores en Mobile

Para poblar dinámicamente los dropdowns en los filtros de búsqueda y el formulario de subida de material sin transferir árboles jerárquicos pesados, Mobile requiere (o solicita formalmente a INT2) los siguientes endpoints independientes:

| Método | Endpoint Requerido | Query / Params | Respuesta esperada | Modelo Mobile |
|---|---|---|---|---|
| **GET** | `/catalog/universities` | — | `UniversityModel[]` | `UniversityModel` |
| **GET** | `/catalog/careers` | `?universityId=<uuid>` | `CareerModel[]` filtrado por universidad | `CareerModel` |
| **GET** | `/catalog/subjects` | `?careerId=<uuid>` | `SubjectModel[]` filtrado por carrera | `SubjectModel` |
| **GET** | `/catalog/professors` | `?subjectId=<uuid>` | `ProfessorModel[]` asociados a la asignatura | `ProfessorModel` |

> 💡 **Estrategia de compatibilidad provisional**: Mientras Backend no exponga las rutas REST individuales arriba listadas, Mobile puede consumir `GET /catalog/filter` y extraer en memoria las listas únicas de Universidades, Carreras y Profesores a partir del árbol de asignaturas devuelto.

---

## 4. Matriz de Estado de Endpoints (Mobile vs. Backend)

| Servicio | Método | Ruta del Endpoint | Estado Backend (INT2) | Estado Mobile (INT4) | Prioridad |
|---|---|---|---|---|---|
| **Auth** | POST | `/api/v1/auth/login` |  Implementado (Mock JWT #92) |  Integrado con `ApiClient` | **P0 (Crítica)** |
| **Auth** | POST | `/api/v1/auth/register` | ⏳ Pendiente (404 en Gateway) |  Maquetado con validaciones | **P0 (Crítica)** |
| **Auth** | GET | `/api/v1/auth/me` | ⏳ Pendiente |  Pantalla de Perfil lista (#57) | **P1 (Alta)** |
| **Auth** | POST | `/api/v1/auth/logout` | ⏳ Pendiente |  Limpieza local implementada | **P2 (Media)** |
| **Auth** | POST | `/api/v1/auth/refresh` | ⏳ Pendiente |  Interceptor preparado | **P2 (Media)** |
| **Catalog**| GET | `/api/v1/catalog/filter` |  Implementado (#71, #97) |  Consumo en Catálogo | **P0 (Crítica)** |
| **Catalog**| GET | `/api/v1/catalog/universities` | ⏳ Solicitado (usar `/filter` alternativo)|  Modelo Dart definido | **P1 (Alta)** |
| **Catalog**| GET | `/api/v1/catalog/careers` | ⏳ Solicitado (usar `/filter` alternativo)|  Modelo Dart definido | **P1 (Alta)** |
| **Catalog**| GET | `/api/v1/catalog/subjects` | ⏳ Solicitado (usar `/filter` alternativo)|  Modelo Dart definido | **P1 (Alta)** |
| **Catalog**| GET | `/api/v1/catalog/professors`| ⏳ Solicitado (usar `/filter` alternativo)|  Modelo Dart definido | **P1 (Alta)** |

---

## 5. Formato Estándar de Errores

El Gateway y los microservicios NestJS responden con el formato RFC / NestJS estándar, el cual es interceptado por `ErrorInterceptor` en Flutter:

```json
{
  "statusCode": 400,
  "message": "El correo debe pertenecer al dominio institucional @uct.cl o @alu.uct.cl",
  "error": "Bad Request"
}
```

En caso de indisponibilidad de microservicios (por ejemplo si Auth Service está caído), el Gateway devuelve:
```json
{
  "statusCode": 502,
  "message": "Auth Service no disponible"
}
```

---

## 6. Endpoints Futuros (Sprint 2+ · Referencia)

### Material Service — `/api/v1/materials`
- `GET /materials` — Listado paginado de materiales con filtros.
- `GET /materials/:id` — Detalle del material y versiones.
- `POST /materials` — Subida multipart de documento (máx. 15MB, PDF/Word/PPT) o enlace externo a video.
- `GET /materials/:id/preview` — URL / Stream para visor embebido.

### Quality Service — `/api/v1/quality`
- `POST /quality/ratings` — Calificación y reseña (1 a 5 estrellas).
- `POST /quality/favorites` / `DELETE /quality/favorites/:id` — Guardar/quitar de favoritos.
- `POST /quality/reports` — Reportar material con motivo obligatorio.

---

## 7. Registro y Evidencia de la Tarea (#58)

- **Issue**: [#58 Actualizar checklist de endpoints requeridos](https://github.com/cchelooo/ApuntesUCT/issues/58)
- **Responsable**: Nelson Quiñinao Isla (Equipo INT4 - Mobile)
- **Evidencia**:
  - Documentación técnica actualizada en este archivo (`docs/checklist-integracion-api-mobile.md`).
  - Rama de trabajo: `feature/issue-58-actualizar-checklist-endpoints`.
  - Pull Request asociado con referencia de cierre (`Closes #58`).
- **Seguimiento de Horas (GitHub Projects)**:
  - Tarea: *Actualizar checklist de endpoints requeridos*
  - Horas asignadas: 2h
  - Horas usadas: 2h
  - Horas restantes: 0h
  - Estado: *Done / Completada*
