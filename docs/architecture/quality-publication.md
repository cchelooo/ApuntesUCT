# Quality: publicación, visibilidad y aplicación de decisiones

Estado: **propuesta 0.1.0 para revisión**, 2026-11-13. Complementa [el contrato externo](../api/quality-contracts.md). No es un registro de funcionalidades ya implementadas.

## 1. Propiedad de los datos

| Servicio | Responsabilidad |
| --- | --- |
| Auth | Usuario, rol singular, actividad, credenciales, emisión/verificación de identidad y revocación |
| Quality | Reglas de moderación, decisiones, evidencia, idempotencia externa, seguimiento de aplicación, notas, reportes y favoritos |
| Material | Contenido y versiones; estado público y verified autoritativos; revision del agregado; validación final y aplicación atómica de transiciones |
| Search | Consultas públicas sobre candidatos que Material permite publicar; no consulta tablas de Quality/Material/Auth |
| Gateway | Enrutamiento y protección de entrada futura; no sustituye la autorización de cada servicio |

Quality puede guardar el resultado histórico de una decisión y la revisión esperada. No mantiene una segunda copia autoritativa del estado público. Material no decide reglas de ranking ni escribe en quality_db. Los servicios se comunican por contratos REST; no comparten clientes Prisma ni claves foráneas.

## 2. Estados canónicos y transiciones

Estados: `PENDING_REVIEW`, `PUBLISHED`, `REJECTED`, `RETIRED`. RETIRED reemplaza el nombre actual WITHDRAWN. No son aliases aceptados simultáneamente en el contrato nuevo.

| Operación | Estado requerido | Estado resultante | verified resultante | Motivo |
| --- | --- | --- | --- | --- |
| APPROVE | PENDING_REVIEW | PUBLISHED | false | Opcional |
| REJECT | PENDING_REVIEW | REJECTED | false | Obligatorio |
| RETIRE | PUBLISHED | RETIRED | false | Obligatorio |
| REOPEN | REJECTED o RETIRED | PENDING_REVIEW | false | Obligatorio |
| VERIFY | PUBLISHED, verified=false | PUBLISHED | true | Opcional |
| REVOKE_VERIFICATION | PUBLISHED, verified=true | PUBLISHED | false | Obligatorio |

MODERATOR/ADMIN activos distintos del autor pueden ejecutar estas operaciones. Todo cambio requiere expectedRevision. Una nueva operación sobre un estado incompatible devuelve 409, incluso si el resultado deseado parece ya alcanzado. Un replay idéntico se resuelve primero por idempotencia y devuelve el resultado original sin repetir la transición.

No hay publicación directa desde REJECTED/RETIRED ni desde el DTO de creación. La creación continúa en PENDING_REVIEW, verified=false. REOPEN no vuelve a publicar; requiere una aprobación posterior.

El retiro por el autor no forma parte de estos endpoints privilegiados. Puede reportar el material con motivo OTHER y una explicación; eso es una solicitud que evalúa otro moderador, sin retiro automático. Un flujo especializado de edición y reenvío del autor pertenece a una tarea posterior de Material. Si se incorpora, debe respetar PENDING_REVIEW y el control de revision. No se inventa una ruta de edición que hoy no existe.

ReviewDecision.REQUEST_CHANGES no se convierte en un quinto estado público. Para este alcance, una devolución que bloquea publicación se expresa como REJECT con motivo explicativo. La evidencia histórica REQUEST_CHANGES existente conserva su significado y no cambia por esta propuesta.

## 3. Verificación y revisión del contenido

Verificar no equivale a aprobar. Solo se verifica un material publicado, y una aprobación deja verified=false. La revocación de verificación no retira el material. Retirar y reabrir sí borran el indicador público, pero conservan evidencia histórica.

Material incorporará `revision` entero positivo al agregado. Inicialmente 1; cada cambio relevante incrementa de forma atómica. Incluye título, descripción, enlace, metadatos académicos, incorporación/sustitución/eliminación de versión, estado y verificación. No basta con comparar updatedAt ni materialVersionId: LINK puede no tener archivo y los metadatos pueden cambiar sin crear versión.

La propuesta conservadora para una edición posterior es volver a PENDING_REVIEW y verified=false si el cambio afecta al contenido o metadatos revisados. Un material RETIRED no se reactiva mediante edición del autor: requiere REOPEN autorizado. La implementación de edición deberá especificar sus permisos y respetar estas invariantes.

Las versiones de archivo son inmutables una vez creadas; una sustitución crea otra versión. El snapshot privado muestra todas las versiones públicamente descargables. La aprobación y verificación de esta etapa abarcan el agregado mostrado en expectedRevision, incluyendo enlace y esas versiones. Review.materialVersionId puede apuntar a la versión actual, pero la operación debe guardar expectedRevision y evidencia suficiente del snapshot (IDs de versiones, checksums o digest del contenido), también para LINK.

**Limitación explícita:** el modelo actual publica el material completo y deja descargar versiones históricas. No se implementa publicación individual por versión. Si una versión histórica no puede ser pública, no se aprueba el agregado hasta resolverlo mediante una política/operación de Material acordada; no se ignora su exposición. Publicar una versión nueva en paralelo a una antigua aprobada exige un contrato/modelo posterior.

## 4. Flujo de aceptación y aplicación

1. El cliente obtiene el snapshot privado y revision.
2. Envía una decisión con expectedRevision e Idempotency-Key a Quality.
3. Quality autentica, autoriza, busca la clave y valida la solicitud. Para una clave nueva consulta Material para comprobar existencia, autoría, revisión y transición. Las comprobaciones previas reducen errores, pero no sustituyen la comprobación atómica final.
4. Quality confirma en una única transacción propia: operación inmutable, asociación de idempotencia, evidencia Review cuando corresponde y trabajo pendiente de entrega (outbox). Solo entonces responde 202 y Location.
5. Un procesador de Quality envía la operación por el contrato privado de Material. Puede ejecutar varios intentos con el mismo operationId; nunca crea una nueva decisión por un fallo de transporte.
6. Material verifica la identidad de servicio/actor y aplica control de idempotencia, revisión y transición dentro de su transacción. Confirma estado, verified, nueva revision y recibo en la misma transacción.
7. Quality registra el recibo y marca APPLIED. Un rechazo definitivo comprobado se marca FAILED; un timeout o error de disponibilidad queda PENDING_APPLICATION y se reconcilia.

No hay transacción distribuida entre bases. El contrato no promete entrega exactamente una vez: usa entrega repetible y efectos idempotentes. El procesamiento asíncrono evita hacer depender la respuesta de decisión de completar toda la comunicación antes del timeout actual del Gateway (5 segundos). No se modifica ese timeout en este PR.

Si Quality no puede confirmar la transacción de aceptación, devuelve 503 cuando sea posible. Si la respuesta se pierde, el cliente reintenta la misma clave: la consulta de idempotencia resuelve si quedó registrada. No anunciar publicación por una respuesta 202 ni por una fila Review.ACCEPT.

## 5. Idempotencia y concurrencia

### En Quality

Clave de moderación: `(actorId, operationFamily, Idempotency-Key)`, donde operationFamily identifica el endpoint de decisiones. La huella incluye materialId de ruta, action, expectedRevision y reason normalizado (ausente/null se normaliza conforme al DTO; el DTO no acepta null para reason). Canonicalizar JSON para que el orden de propiedades no cambie la huella. No incluir secretos ni tokens.

- Misma clave/actor/familia y misma huella: misma operación; 202 mientras pendiente, 200 cuando terminal.
- Misma clave y otra huella, incluso otro material: 409 IDEMPOTENCY_CONFLICT.
- Claves distintas: operaciones distintas, sujetas a expectedRevision y transiciones.
- Autenticar y comprobar acceso antes de devolver un replay. Un usuario diferente no obtiene la operación de otro por adivinar su clave.
- Mantener el registro de decisiones y sus claves durante toda la vida del historial; sin expiración automática en esta primera versión. La futura política de retención deberá preservar una marca que impida reaplicar operaciones antiguas.

Aplicar el mismo patrón a POST de reportes y PATCH de tratamiento, con familias separadas. Mantener snapshots de respuesta de esas operaciones: un replay no reejecuta efectos ni restablece estados posteriores. PUT/DELETE de favoritos y calificaciones obtienen idempotencia por recurso propio y restricciones únicas, sin Idempotency-Key.

### En Material

El identificador generado por Quality es la clave: `(issuerService, operationId)`. Guardar materialId, actorId/role, huella de orden, recibo y efecto. Buscar el recibo antes de comprobar expectedRevision o transición. Si se reenvía exactamente la orden ya aplicada, devolver el recibo original aunque el material haya cambiado después. Si cambian actor, material o contenido para ese operationId:409.

Para una orden nueva, bloquear/actualizar condicionalmente el agregado y comprobar expectedRevision, autoría y transición. Cambio de status/verified, incremento de revision y creación del recibo pertenecen a una sola transacción local. Dos decisiones sobre la misma revision no pueden confirmarse ambas. No usar una secuencia de lectura y actualización sin condición atómica.

Ante timeout de aplicación:

- Quality puede consultar GET del recibo por operationId y/o repetir el mismo PUT.
- Un GET 404 no demuestra rollback: la primera solicitud podría confirmar después. Reintentar el mismo PUT, no emitir otra orden ni cambiar expectedRevision.
- Un 400/403/404/409 definitivo recibido por el PUT autorizado puede registrarse como FAILED; antes de resolver carreras con entregas previas inciertas, Material debe haber serializado/consultado el registro idempotente de esa operación. El contrato exige esa garantía, no una simple caché de respuestas.
- 401 del servicio, 5xx, respuesta inválida o fallos de red requieren resolver configuración/reconciliar; no se convierten en una nueva decisión de negocio. Exponer solo seguimiento sanitizado y alertar al operador.
- Si Material confirmó pero Quality falló al registrar el recibo, el reintento recupera el mismo resultado.

Una operación FAILED exige nueva lectura y nueva decisión/clave si el usuario desea actuar otra vez. No actualizar silenciosamente expectedRevision a la versión más reciente.

## 6. Autorización entre servicios

Contrato privado: [material-quality-internal.openapi.json](../api/material-quality-internal.openapi.json), bajo `/internal/v1/quality`. No está bajo `/api/v1/materials`, para evitar que el wildcard público actual lo capture. No añadir una ruta genérica del Gateway que lo publique. Restringir también su acceso por red; la ubicación interna no sustituye autenticación.

Propuesta concreta para acordar con Auth/infraestructura:

- Quality usa una clave asimétrica de servicio distinta de las claves de usuario. Material confía únicamente en su clave pública configurada; nunca acepta la clave indicada libremente por el cliente.
- Aserción JWT de servicio con algoritmo permitido RS256, issuer/sub `quality-service`, audience `material-service`, exp máximo 60 s, iat, jti y scopes específicos. Proteger el transporte con TLS en entornos compartidos. No usar secretos ni tokens reales en documentación o fixtures.
- `material:review:read` para listar/leer/descargar privados. `material:quality:apply` para aplicar/reconciliar decisiones. Material exige estos scopes y actor MODERATOR/ADMIN.
- La aserción incluye actorId, actorRole, authorizedAt y, para aplicación/reconciliación, operationId. Son afirmaciones firmadas por un servicio de confianza, no headers libres ni campos editables por el cliente.
- Para lecturas privadas Quality verifica la sesión vigente antes de emitir la aserción. Para decisiones se conserva la autorización verificada al aceptar duraderamente la operación. Los reintentos automáticos actúan sobre esa operación aceptada y no sobre una nueva sesión del cliente.
- Política propuesta: una decisión aceptada conserva autorización para completarse aunque el actor cierre sesión o pierda el rol después; no existe cancelación implícita. La interfaz requiere autorización actual para consultar/reintentar desde el usuario. Si el equipo exige revocación de decisiones en cola, debe cambiar explícitamente esta política y diseñar su cancelación antes del acuerdo.
- Material valida que operationId firmado coincide con la ruta, actor con el recibo/historial y que el actor no sea uploaderId. No acepta el JWT de login mock ni un JWT de usuario en estas rutas de servicio.

No existe todavía este emisor de servicio ni la autenticación real de usuario. Este PR solo acuerda el mecanismo objetivo. Hasta implementarlo y probarlo, las rutas privadas deben permanecer deshabilitadas/cerradas; no habilitar un modo de moderador de desarrollo mediante variables como sustituto en producción.

## 7. Visibilidad pública y Search

| Estado Material | Listado/búsqueda públicos | Detalle público | Descarga pública |
| --- | --- | --- | --- |
| PENDING_REVIEW | Excluido | 404 | 404 |
| PUBLISHED | Incluido si coincide con búsqueda/filtros | 200 si es válido | 200 si existe archivo/versión |
| REJECTED | Excluido | 404 | 404 |
| RETIRED | Excluido | 404 | 404 |

verified no concede visibilidad: un material oculto con un dato inconsistente verified=true tampoco se expone. Las consultas públicas de Material mantienen `where status=PUBLISHED`. La descarga verifica también pertenencia de versionId. El bucket no es público y no se devuelven storageKey o URLs persistentes.

Search sigue consumiendo GET público de Material. No aplica decisiones en quality_db, no confía en Review.ACCEPT ni usa un estado público duplicado. En esta versión no se introduce índice persistente ni caché de resultados públicos; las lecturas nuevas posteriores a una transición confirmada usan el estado confirmado de Material, sin réplicas retrasadas para la decisión de acceso. Si más adelante se añade caché/índice, se necesitará invalidación y una comprobación autoritativa antes de exponer recursos ocultos, documentadas antes de habilitarlo.

Garantía temporal: una solicitud pública cuya comprobación autoritativa ocurre después del commit del retiro no obtiene el recurso. No es posible recuperar bytes ya enviados, documentos ya descargados ni controlar una URL externa previamente conocida. Una búsqueda o descarga que ya estaba en curso puede haber leído el estado anterior; no se promete revocación retroactiva ni una instantánea entre páginas. El contrato actual de Material ya realiza esta comprobación por solicitud; una exigencia de revocación de streams activos requeriría una tarea específica.

## 8. Evolución de persistencia requerida, no ejecutada por este PR

### Material

1. Resolver RETIRED en código/contrato y base de datos sin perder registros existentes.
2. Incorporar revision y actualizar todos los caminos de escritura relevantes.
3. Incorporar recibo durable de aplicación idempotente, único por servicio/operationId.
4. Añadir casos de uso privados y controles de identidad/rol/autoría.

No editar una migración ya aplicada ni usar reset. Dos estrategias posibles para RETIRED: renombrar el valor PostgreSQL mediante una nueva migración con despliegue coordinado, o usar temporalmente `RETIRED @map("WITHDRAWN")` en Prisma para que el API/cliente generado use el nombre canónico conservando el valor físico. Esta segunda opción es solo una compatibilidad de almacenamiento explícita, no dos estados públicos. Elegir una sola estrategia en la tarea de implementación y probar datos existentes y reinicios. No ejecutar cambios de esquema desde este paquete documental.

### Quality

Los cuatro modelos aprobados se conservan. Se requieren ampliaciones para hacer efectivos los contratos:

- ModerationOperation y outbox durables, claves/huellas de idempotencia y seguimiento PENDING_APPLICATION/APPLIED/FAILED, actor, action, expectedRevision, reason, recibo y errores sanitizados.
- Evidencia inmutable del contenido revisado y vínculo de Review a la operación cuando corresponda.
- Mapear APPROVE→Review(MODERATION,ACCEPT), REJECT→Review(MODERATION,REJECT), VERIFY→Review(VERIFICATION,ACCEPT). RETIRE/REOPEN/REVOKE_VERIFICATION se auditan como acciones de operación; no forzar su significado en ReviewDecision.REJECT.
- Reportes: resolutionNote, historial de tratamiento, idempotencia de creación/actualización y garantía de un reporte abierto por usuario/material (índice único parcial para OPEN/IN_REVIEW o mecanismo transaccional equivalente).
- Mantener unique(materialId,userId) en Rating/Favorite y CHECK de score 1..5.

No se agregan columnas de publicación autoritativas a Quality ni FKs a Material/Auth. `result.status` del recibo es evidencia histórica, no estado actual para responder a búsquedas.

## 9. Trabajo posterior y límites de aprobación

Aprobar este PR acuerda contratos; no habilita endpoints. La implementación deberá entregar autenticación de usuario, aserciones de servicio, migraciones, endpoints, outbox/reconciliación, conexión del Gateway e integración Web/Mobile con los escenarios de prueba definidos. Se pueden usar mocks de identidad en pruebas y UI de prototipo, claramente separados de un entorno real. Ningún mock acredita permisos de producción.

## Referencias técnicas

- [RFC 9110: semántica HTTP](https://www.rfc-editor.org/rfc/rfc9110.html).
- [RFC 8725: buenas prácticas JWT](https://www.rfc-editor.org/rfc/rfc8725.html).
- [OWASP REST Security](https://cheatsheetseries.owasp.org/cheatsheets/REST_Security_Cheat_Sheet.html).
- [Prisma: nombres de enum y mapeo](https://www.prisma.io/docs/orm/v6/prisma-schema/data-model/database-mapping).

Estas referencias fundamentan decisiones de protocolo y seguridad; no sustituyen el acuerdo del equipo sobre permisos y políticas de producto.
