# Checklist de Integración API — Mobile (INT4)
 
**Sprint 1 · Semana 1** — Lista de endpoints, datos y validaciones que INT4 necesita para integrarse con la API (ApuntesUCT, arquitectura de microservicios detrás de un API Gateway NestJS).
 
> Estado: borrador basado en los documentos de Requisitos F/NF, Reglas de Negocio y el MER de microservicios. Las rutas exactas deben confirmarse contra el Swagger/OpenAPI real una vez publicado por INT2 — ver sección 4.
 
---
 
## 1. Endpoints por servicio (vía API Gateway)
 
### Auth Service — `/api/v1/auth`
 
| Método | Endpoint | Body / Params | Respuesta esperada | Validaciones clave |
|---|---|---|---|---|
| POST | `/auth/register` | `name`, `email`, `password` | `UserModel` (sin passwordHash) | Email debe terminar en `@uct.cl` o `@alu.uct.cl` (RF-01, RN-U01) |
| POST | `/auth/login` | `email`, `password` | `accessToken` (+ `refreshToken`?) y `UserModel` | — |
| POST | `/auth/refresh` | `refreshToken` | nuevo `accessToken` | Existe `USER_SESSION.refreshTokenHash` en el MER — confirmar si expone endpoint propio |
| POST | `/auth/logout` | — (usa token de sesión) | 204 / confirmación | Revoca la sesión activa |
| POST | `/auth/forgot-password` / `/auth/reset-password` | email / token+nueva password | confirmación | Mencionado en RF-01 ("recuperación de contraseña"), sin detalle técnico aún |
 
### Catalog Service — `/api/v1/catalog`
 
| Método | Endpoint | Params | Respuesta | Notas |
|---|---|---|---|---|
| GET | `/catalog/universities` | — | `UniversityModel[]` | |
| GET | `/catalog/careers` | `universityId` | `CareerModel[]` | |
| GET | `/catalog/subjects` | `careerId` | `SubjectModel[]` | |
| GET | `/catalog/professors` | `subjectId` | `ProfessorModel[]` | |
| GET | `/catalog/academic-offerings` | `careerId`, `subjectId`, `year`, `term` | lista de ofertas | Necesario para armar el combo Carrera→Asignatura→Profesor→Año al subir material (RF-02) |
 
### Material Service — `/api/v1/materials`
 
| Método | Endpoint | Body / Params | Respuesta | Validaciones clave |
|---|---|---|---|---|
| GET | `/materials` | filtros: `careerId`, `subjectId`, `professorId`, `year`, `materialType`, `rating` | `MaterialModel[]` paginado | RF-04 — confirmar formato de paginación con INT2 |
| GET | `/materials/:id` | — | `MaterialModel` + versiones | |
| POST | `/materials` | multipart: `title`, `description`, `careerId`, `subjectId`, `professorId`, `academicOfferingId`, `materialTypeId`, `academicYear`, `file` o `videoUrl` | `MaterialModel` (status `PENDING_REVIEW`) | Formatos permitidos: PDF/PPT/Word, **máx. 15MB** (RN-M05, RF-02). Videos: solo enlace externo, nunca archivo (RN-M06) |
| GET | `/materials/:id/versions` | — | `MaterialVersionModel[]` | |
| GET | `/materials/:id/preview` | — | URL/stream para visor embebido | RF-05 |
 
### Quality Service — `/api/v1/quality`
 
| Método | Endpoint | Body | Respuesta | Validaciones clave |
|---|---|---|---|---|
| POST | `/quality/ratings` | `materialId`, `score` (1–5), `comment` | `RatingModel` | Un usuario solo puede tener **una** calificación activa por material (UNIQUE) — Mobile debe permitir *editar*, no duplicar (RF-06) |
| GET | `/quality/materials/:id/ratings` | — | `RatingModel[]` | |
| POST | `/quality/favorites` | `materialId` | confirmación | |
| DELETE | `/quality/favorites/:materialId` | — | confirmación | |
| POST | `/quality/reports` | `materialId`, `type`, `reason` | `ReportModel` | El reporte **requiere motivo** (RN-REP02); no elimina el material automáticamente (RN-REP04) |
| GET | `/quality/reputation/:userId` | — | puntaje de reputación | RF-06 |
 
### Search Service — `/api/v1/search`
 
| Método | Endpoint | Params | Respuesta | Notas |
|---|---|---|---|---|
| GET | `/search` | `q`, `careerId`, `subjectId`, `professorId`, `year`, `rating` | resultados + `verified` flag | RF-04 — autocompletado y filtros combinados; según RNF-02, la respuesta no debería superar 1.5s |
 
---
 
## 2. Modelos de datos que Mobile necesita (confirmado por el MER)
 
`UserModel`, `UniversityModel`, `CareerModel`, `SubjectModel`, `ProfessorModel`, `MaterialModel`, `MaterialVersionModel`, `RatingModel`, `ReportModel`, `FavoriteModel`
 
Estados de `MaterialModel.status` que la UI debe contemplar: `PENDING_REVIEW`, `PUBLISHED`, `REJECTED`, `REMOVED`.
 
---
 
## 3. Validaciones / reglas de negocio que Mobile debe reflejar en la UI
 
- Registro restringido a correos institucionales `@uct.cl` / `@alu.uct.cl` (RF-01, RN-U01).
- Un material recién subido entra en estado "En revisión" — **no mostrarlo como público** hasta que esté `PUBLISHED` (RN-M07, RN-M08).
- Archivos: solo PDF, PPT o Word, máximo 15MB (RN-M05). Si el usuario intenta subir otro formato o un archivo más pesado, debe bloquearse en el cliente antes de llamar a la API.
- Videos: la app nunca sube el archivo, solo guarda un enlace externo (YouTube/Drive) (RN-M06).
- Reportes: el formulario debe **exigir un motivo** antes de habilitar el envío (RN-REP02).
- Calificaciones: si el usuario ya calificó ese material, la UI debe mostrar su calificación existente y permitir editarla, no crear una nueva.
---
 
## 4. Pendiente de confirmar con el equipo backend (INT2)
 
- [ ] Rutas exactas una vez esté publicado el Swagger/OpenAPI real (las de este documento son la mejor inferencia a partir de los requisitos, no están verificadas contra la API).
- [ ] Esquema de autenticación: ¿JWT en header `Authorization: Bearer`? ¿Duración del token?
- [ ] Formato de paginación en listados (`page`/`limit` vs. cursor).
- [ ] Formato estándar de error (¿`{ statusCode, message, error }` tipo NestJS por defecto, o uno custom?).
- [ ] Endpoint(s) de recuperación de contraseña — sin definir en los documentos actuales.
---
 
*Elaborado por INT4 a partir de: Especificación de Requisitos (RF/RNF), Reglas de Negocio, y MER por microservicio de ApuntesUCT.*
