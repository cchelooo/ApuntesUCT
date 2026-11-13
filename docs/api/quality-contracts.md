# Contratos de Quality Service

Versión de propuesta: 0.1.0 — 2026-11-13.

**Estado: PROPUESTO PARA ACUERDO.** Este documento especifica comportamiento futuro. No acredita que los endpoints funcionales estén implementados, desplegados o protegidos actualmente. La aprobación del PR debe registrar el acuerdo de Backend, Web y Mobile. `RETIRED` es el nombre canónico elegido para esta propuesta a petición del responsable de la tarea.

## 1. Alcance y fuentes

Define moderación, publicación, verificación, retiro, calificaciones, reportes y favoritos. Las estructuras y rutas exactas se encuentran en [quality.openapi.json](quality.openapi.json). La integración privada de Material está en [material-quality-internal.openapi.json](material-quality-internal.openapi.json). La implementación que habrá que realizar se describe en [quality-publication.md](../architecture/quality-publication.md).

Base revisada: esquemas Prisma de Auth/Material/Quality, login mock de Auth, MaterialAuthorProvider, MaterialsService.list/detail/download, módulos y proxy de Gateway suministrados por el equipo. Los nombres de archivos son referencias al código revisado, no una afirmación de que este paquete inspeccionó el repositorio completo.

| Estado actual comprobado | Alcance de este contrato |
| --- | --- |
| Quality tiene persistencia, `/health` y documentación | Diseñar sus operaciones funcionales; no sustituir la implementación de salud |
| Auth tiene Role singular STUDENT/MODERATOR/ADMIN, pero login mock sin firma | Exigir identidad real y permisos antes de habilitar operaciones protegidas |
| Gateway no registra autenticación en los archivos revisados ni ruta Quality | Especificar integración y protección futuras |
| Material utiliza WITHDRAWN | Adoptar RETIRED con adaptación y migración compatibles |
| Material lista, detalla y descarga solo PUBLISHED | Conservar esa frontera pública y añadir acceso privado independiente |
| Search consume candidatos de Material por REST | Conservar la exclusión de materiales ocultos, sin consultas a bases ajenas |

No se incorporan valoración en Search, cálculo de reputación, ranking, edición de usuarios ni acceso a bases ajenas.

## 2. Autenticación, roles y autorización

Todas las operaciones requieren usuario activo autenticado, salvo el resumen público de calificaciones. `Authorization: Bearer <accessToken>` es el contrato externo. El JWT objetivo debe ser firmado: propuesta RS256, emisor de Auth configurado, audiencia que incluya Quality, `sub` UUID, un `role` de los tres definidos, `iat` y `exp`; validar firma, algoritmo permitido, emisor, audiencia, vigencia y revocación/actividad según el mecanismo real acordado con Auth. Validar `nbf` si existe. No basta con decodificar el payload. Claves, valores de issuer/audience y mecanismo de desactivación se acuerdan antes de conectar clientes reales.

El token actual con `alg:none`/`mock:true`, un Bearer arbitrario y las variables MATERIAL_LOCAL_* no autentican estas operaciones. Rechazarlos con 401. Un usuario autenticado cuya cuenta esté inactiva devuelve 403. Un token revocado devuelve 401. La comprobación de actividad/revocación puede usar el contrato de Auth o su mecanismo de invalidación verificado; nunca leer auth_db. Si esa dependencia requerida falla, devolver 503 sin conceder acceso.

Cada servicio debe proteger sus operaciones; el Gateway no es la única frontera. `userId`, `actorId`, `role`, `status` y `verified` no se aceptan como atribuciones libres del cliente. Los DTO de escritura son cerrados: propiedades desconocidas devuelven 400. Los encabezados `x-user-id`, `x-role` o equivalentes no son fuente confiable de identidad.

| Operación | STUDENT | MODERATOR | ADMIN |
| --- | --- | --- | --- |
| Leer resumen público de notas de un material publicado | Sí, también anónimo | Sí | Sí |
| Crear/actualizar/eliminar calificación propia | Sí | Sí | Sí |
| Crear y consultar reportes propios | Sí | Sí | Sí |
| Guardar/listar/eliminar favoritos propios | Sí | Sí | Sí |
| Consultar material privado y descargar para revisión | No | Sí | Sí |
| Aprobar/rechazar/verificar/revocar verificación/retirar/reabrir revisión | No | Sí | Sí |
| Consultar y tramitar reportes de terceros | No | Sí | Sí |
| Modificar notas o favoritos ajenos | No | No | No |

Restricciones adicionales: nadie puede decidir sobre su propio material ni calificarlo, incluido ADMIN. Consultar el material propio sí se permite a moderadores. Un moderador no tramita un reporte presentado por sí mismo ni referido a un material suyo. Puede reportar material propio y otro moderador tramita el caso. ADMIN no tiene una excepción implícita: cualquier futura excepción requerirá un cambio de contrato y auditoría.

Un STUDENT que intenta una ruta de moderación recibe 403 antes de consultar el recurso. Un usuario que intenta leer el reporte de otro mediante su ID recibe 404, para no confirmar su existencia. Nunca se entrega contenido privado mediante favoritos, reportes o calificaciones.

## 3. Convenciones HTTP y DTO

Prefijo externo: `/api/v1/quality`, a través del Gateway futuro. Los servidores `example.invalid` de OpenAPI son ilustrativos. El servicio directo sigue teniendo puerto interno 3004, pero Web/Mobile no deben depender de él.

- UUID en identificadores de ruta y claves de idempotencia. Fechas UTC ISO 8601. `score` y `expectedRevision` son números enteros JSON, no cadenas.
- `page` por defecto 1, mínimo 1, máximo 2147483647; `pageSize` por defecto 20, entre 1 y 100. Parámetros repetidos, desconocidos, vacíos o no enteros: 400. Offset superior a 2147483647: 400.
- Páginas: `{items, page, pageSize, total}`. Página fuera de rango: 200, `items:[]`, total conservado. Orden fijo `createdAt DESC, id DESC`; no hay nuevos filtros/ordenamientos arbitrarios en este contrato.
- `total` cuenta los registros accesibles por el contrato correspondiente. La página y su conteo usan una lectura coherente dentro de su servicio; páginas separadas no forman una instantánea durante escrituras concurrentes.
- Cadenas justificativas se recortan en extremos; no se admiten motivos formados solo por espacios. No se cambia el contenido de documentos ni URLs mediante esta normalización.
- Las respuestas privadas y públicas que dependan de visibilidad usan `Cache-Control: no-store` en esta etapa.
- No exponer claves MinIO, contraseñas, tokens, trazas ni errores de PostgreSQL. `fileSize` de versiones es cadena decimal en bytes, como en el detalle actual de Material.

Los DTO exactos de campos obligatorios, opcionales, límites, enums y ejemplos son los componentes de OpenAPI. Las reglas entre campos se especifican aquí y en sus descripciones; no todas son expresables mediante los keywords básicos de OpenAPI 3.0.

## 4. Moderación y acceso privado

Todos estos endpoints requieren MODERATOR o ADMIN activo.

| Método y ruta, respecto al prefijo | Solicitud | Respuesta |
| --- | --- | --- |
| GET `/moderation/materials` | status opcional, por defecto PENDING_REVIEW; page/pageSize | 200 ModerationMaterialPageDto |
| GET `/moderation/materials/{materialId}` | UUID | 200 ModerationMaterialDto con revision |
| GET `/moderation/materials/{materialId}/versions/{versionId}/download` | UUID de material y versión | 200 stream, 404 si no existe o no pertenece |
| POST `/moderation/materials/{materialId}/decisions` | Idempotency-Key + ModerationDecisionRequestDto | Nueva: 202; replay pendiente: 202; replay terminal: 200 |
| GET `/moderation/operations/{operationId}` | UUID | 200 ModerationOperationDto |

`ModerationMaterialDto` es un snapshot privado con estado, verificación, propietario, contenido descriptivo, enlace, versiones y `revision`. No contiene storageKey. Se obtiene por REST de Material, nunca por SQL desde Quality.

La descarga privada admite cualquier estado, valida pertenencia de versión, conserva MIME, Content-Length y Content-Disposition attachment y responde no-store. No entrega URL firmada reutilizable ni hace público el bucket. LINK sin archivo devuelve 404 al descargar; su URL aparece en el snapshot privado. El backend no sigue esa URL ni promete controlar el acceso en el sitio externo.

Ejemplo de decisión:

```http
POST /api/v1/quality/moderation/materials/22222222-2222-4222-8222-222222222222/decisions
Authorization: Bearer <TOKEN_REAL>
Idempotency-Key: 44444444-4444-4444-8444-444444444444
Content-Type: application/json

{"action":"APPROVE","expectedRevision":4}
```

Los IDs son ilustrativos; se sustituyen por valores reales. `reason` es obligatorio para REJECT, RETIRE, REOPEN y REVOKE_VERIFICATION (1..2000 caracteres con contenido). APPROVE y VERIFY lo admiten opcionalmente.

Respuesta nueva:

```json
{
  "id": "33333333-3333-4333-8333-333333333333",
  "materialId": "22222222-2222-4222-8222-222222222222",
  "actorId": "11111111-1111-4111-8111-111111111111",
  "action": "APPROVE",
  "reason": null,
  "expectedRevision": 4,
  "state": "PENDING_APPLICATION",
  "result": null,
  "failure": null,
  "createdAt": "2026-11-13T15:00:00Z",
  "updatedAt": "2026-11-13T15:00:00Z"
}
```

Incluye `Location: /api/v1/quality/moderation/operations/33333333-3333-4333-8333-333333333333`. **202 no significa publicado.** La UI consulta Location con espera progresiva (propuesta 1, 2, 5 segundos, luego 5); ofrece seguimiento y permite detener el sondeo sin cancelar la decisión. Si el Gateway pierde la respuesta, reenvía el mismo POST con la misma clave.

- PENDING_APPLICATION: aún no hay confirmación; result y failure son null.
- APPLIED: Material confirmó un recibo durable; result no es null y failure es null.
- FAILED: rechazo definitivo; failure no es null y result es null. No se reintenta automáticamente con una revisión nueva.

GET siempre devuelve 200 si pudo leer la operación, incluso FAILED. Un replay terminal también devuelve 200: el cliente interpreta `state`, no lo confunde con éxito de publicación. `result` describe el efecto histórico de esa operación; otra decisión posterior pudo cambiar el material.

Transiciones y seguridad de la integración se especifican en [quality-publication.md](../architecture/quality-publication.md).

## 5. Calificaciones

| Método y ruta | DTO | Respuesta |
| --- | --- | --- |
| GET `/materials/{materialId}/ratings/summary` | Sin autenticación | 200 RatingSummaryDto; oculto/inexistente: 404 |
| GET `/materials/{materialId}/ratings/me` | Usuario autenticado | 200 RatingDto; sin nota o material oculto: 404 |
| PUT `/materials/{materialId}/ratings/me` | RatingUpsertDto | 201 si crea; 200 si actualiza o repite |
| DELETE `/materials/{materialId}/ratings/me` | Sin cuerpo | 204 aunque no exista |

Una calificación por usuario/material, score entero 1..5 y comment opcional/null hasta 2000 caracteres. PUT reemplaza el contenido: comment omitido elimina el comentario previo. Repetir un PUT idéntico conserva id, createdAt y updatedAt. Operaciones distintas concurrentes se serializan en la persistencia; la última confirmada es la vigente, sin duplicados.

Solo se crean/actualizan notas sobre materiales PUBLISHED y de otro autor. La eliminación propia se permite aunque el material esté oculto o eliminado: no devuelve metadatos y no exige consultar Material. Las notas de un material retirado se conservan para auditoría; resumen y lectura pública devuelven 404. Si vuelve a publicarse, las notas existentes reaparecen: en esta versión pertenecen al material, no a una versión. La UI no debe interpretarlas como evaluación exclusiva de la nueva versión.

El resumen es `{materialId,count,average}`; count=0 implica average=null; si hay notas se redondea a dos decimales. No devuelve identidades. Se mantiene el CHECK PostgreSQL 1..5 además de validar HTTP.

## 6. Reportes

| Método y ruta | DTO | Respuesta |
| --- | --- | --- |
| POST `/materials/{materialId}/reports` | ReportCreateDto + Idempotency-Key | 201 nuevo, 200 replay |
| GET `/reports/me` | page/pageSize | 200 ReportPageDto propio |
| GET `/reports/{reportId}` | Denunciante o moderador/admin | 200 ReportDto |
| GET `/moderation/reports` | status opcional; page/pageSize | 200 ReportPageDto |
| PATCH `/moderation/reports/{reportId}` | ReportUpdateDto + Idempotency-Key | 200 ReportDto |

Motivos: INAPPROPRIATE_CONTENT, COPYRIGHT, INCORRECT_INFORMATION, BROKEN_RESOURCE, OTHER. `details` opcional/null hasta 2000; OTHER exige contenido no vacío. Solo se crean sobre PUBLISHED. Crear reporte no retira ni desverifica automáticamente.

Máximo un reporte OPEN o IN_REVIEW por usuario/material; una nueva clave para otro reporte abierto devuelve 409 REPORT_ALREADY_OPEN. Tras un reporte terminal se puede crear uno nuevo. Misma clave/payload devuelve el reporte original aunque ya sea terminal; clave reutilizada con otro cuerpo devuelve 409 IDEMPOTENCY_CONFLICT. El replay no crea un reporte nuevo ni divulga metadatos actuales del material.

Tratamiento: OPEN → IN_REVIEW, RESOLVED o DISMISSED; IN_REVIEW → RESOLVED o DISMISSED. Los terminales no se reabren. `resolutionNote` es obligatoria al resolver o descartar (1..2000). `expectedUpdatedAt` debe coincidir con el valor leído; comprobación y escritura atómicas. El timestamp debe cambiar estrictamente al modificar para no permitir pérdida de actualizaciones en el mismo milisegundo; una alternativa posterior sería un revision entero mediante nueva versión de contrato.

La idempotencia de PATCH se comprueba antes de expectedUpdatedAt. Repetir la misma clave/payload devuelve el snapshot guardado. Una transición con una clave nueva que ya no sea aplicable devuelve 409. Los cambios registran actor, fecha, estado anterior y nuevo. No se cambian `reason`, `details` ni identidad del denunciante por esta ruta.

Resolver un reporte no cambia Material: retirar requiere una decisión RETIRE aparte. Los reportes propios pueden consultarse tras ocultarse Material, sin incluir título, enlace ni archivo. Quien reportó el caso, o sea autor del material, no lo resuelve por sí mismo.

## 7. Favoritos

| Método y ruta | Respuesta |
| --- | --- |
| PUT `/materials/{materialId}/favorite` sin cuerpo | 201 nuevo, 200 si ya existe |
| DELETE `/materials/{materialId}/favorite` sin cuerpo | 204 aunque no exista |
| GET `/favorites/me?page=1&pageSize=20` | 200 FavoritePageDto |

Solo se agregan materiales PUBLISHED; se permite guardar material propio. Una relación por usuario/material. Repetir PUT conserva id y createdAt. Un favorito existente cuyo material ya no sea visible no habilita el PUT: devuelve 404. DELETE elimina la relación propia sin consultar Material ni revelar sus datos.

La lista pagina relaciones propias y total cuenta esas relaciones, incluidas las no disponibles. Cada item contiene solamente id, materialId, createdAt y available. Si Material confirma oculto/inexistente, available=false; no se devuelve título, enlace, estado privado, versión ni URL de descarga. Para mostrar detalles de available=true el cliente usa el detalle público de Material, que puede devolver 404 si cambió entretanto.

Si falla la comprobación de Material se devuelve 502/503, no se simula available=false ni se sirve una copia anterior. La verificación se realiza solo para la página solicitada, con concurrencia acotada; nunca se escanean todos los favoritos para calcular el total.

## 8. Errores estables

Sobre propuesto: `{statusCode, code, message, requestId, field?}`. `field` se conserva cuando corresponde a un campo; no inventar un campo para todos los errores. El contrato exige adaptar el filtro HTTP futuro; no afirma que el filtro actual de Material ya produzca este formato para sus rutas públicas existentes.

| HTTP | code orientativo | Cuándo |
| --- | --- | --- |
| 400 | VALIDATION_ERROR | UUID, DTO, enum, rango, paginación o motivo inválido |
| 401 | UNAUTHENTICATED | Token ausente, falso, mock, vencido o revocado; incluir WWW-Authenticate: Bearer |
| 403 | FORBIDDEN / SELF_REVIEW_FORBIDDEN / SELF_RATING_FORBIDDEN | Rol insuficiente, cuenta inactiva o conflicto de autoría |
| 404 | NOT_FOUND | Recurso no existe, no es visible o no pertenece al usuario/versión solicitados |
| 409 | INVALID_TRANSITION / STALE_REVISION / IDEMPOTENCY_CONFLICT / REPORT_ALREADY_OPEN | Conflicto de estado, revisión, clave o reporte abierto |
| 502 | DEPENDENCY_INVALID_RESPONSE | Respuesta ajena inválida o inconsistente |
| 503 | DEPENDENCY_UNAVAILABLE | Dependencia o persistencia no disponible |

El error 502 de transporte del Gateway actualmente tiene su propio sobre; Web/Mobile deben distinguirlo y tratarlo como error de infraestructura. Este PR no modifica ese contrato global. Una operación de decisión ya aceptada cuyo despacho falle permanece pendiente y consultable; no se transforma en éxito ni se elimina para responder 503.

Comprobar autenticación y permiso de ruta antes de cargar datos privados. Una petición válida puede recibir después 404/409 según visibilidad o conflicto; no usar 403 para revelar que un material oculto existe en una ruta pública.

## 9. Condiciones de aceptación y acuerdos

Este documento y ambos OpenAPI deben revisarse juntos. Los cambios posteriores requieren actualizar todos los contratos afectados, los ejemplos y la matriz de pruebas. No afirmar que la tarea está acordada hasta completar el registro en [quality-contracts-acceptance.md](../testing/quality-contracts-acceptance.md).

El formato del contrato se apoya en [OpenAPI 3.0.3](https://spec.openapis.org/oas/v3.0.3.html). Los significados HTTP siguen [RFC 9110](https://www.rfc-editor.org/rfc/rfc9110.html); en especial 202 expresa aceptación sin finalización. La separación entre token, firma y autorización por endpoint sigue [OWASP REST Security](https://cheatsheetseries.owasp.org/cheatsheets/REST_Security_Cheat_Sheet.html). Las políticas de producto (roles, autorrevisión, versiones y transiciones) son decisiones propuestas del equipo, no requisitos impuestos por esas referencias.
