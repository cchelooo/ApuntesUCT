# Quality: publicación, visibilidad y aplicación de decisiones

Estado: **propuesta 0.1.0 para revisión**, 2026-11-13. Complementa [el contrato externo](../api/quality-contracts.md).
No es un registro de funcionalidades ya implementadas.

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

### 3.1. Calificaciones al republicar

La propuesta sometida a confirmación es conservar las calificaciones
asociadas al material cuando se rechaza o retira y volver a incluirlas
en su resumen público cuando se publica nuevamente.

Las calificaciones pertenecen al material, no exclusivamente a su versión
más reciente. Mientras el material permanezca oculto, su resumen no se
expone mediante rutas públicas.

La conservación de calificaciones no concede visibilidad ni sustituye
una nueva aprobación.

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

## 6. Autorización y dependencia del contrato S3-05

La identidad de usuario y la propagación de credenciales se rigen por
[S3-05 / #445 — Contrato de autorización entre servicios](https://github.com/cchelooo/ApuntesUCT/issues/445),
documentado en [contrato-autorizacion-entre-servicios.md](../api/contrato-autorizacion-entre-servicios.md).

S3-05 está consensuado. Su aprobación documental no implica que la emisión
de JWT reales, la validación de credenciales o los permisos ya estén
implementados.

### 6.1. Identidad de usuario

Quality adopta las reglas comunes de S3-05:

- El cliente utiliza `Authorization: Bearer <access_token>`.
- El Gateway propaga el token sin modificarlo.
- La identidad procede de credenciales verificadas; `sub` corresponde al
  UUID de `user.id`.
- Los roles son `STUDENT`, `MODERATOR` y `ADMIN`.
- `ADMIN` incluye los permisos de `MODERATOR`, sujeto a las mismas
  restricciones de autoría y conflicto de interés del contrato Quality.
- Se verifica la firma y la vigencia del token, así como el emisor y la
  audiencia conforme a la configuración acordada con Auth.
- Los identificadores y roles enviados libremente en el body o en
  encabezados del cliente no acreditan identidad ni permisos.
- Credenciales ausentes, inválidas o expiradas producen `401`.
- Una identidad válida sin permiso para la operación produce `403`.

Las rutas reales de moderación y acceso privado de Quality no aceptarán
tokens mock ni `alg: none`. Los mocks podrán utilizarse en pruebas aisladas,
sin otorgar acceso a materiales o archivos privados reales.

Los valores de emisor, audiencia, algoritmos admitidos, distribución de
claves y mecanismos de comprobación de actividad o revocación deberán
proceder de la implementación y los acuerdos de Auth. Este documento no
los declara implementados ni los sustituye por configuración local de
moderador.

### 6.2. Comunicación Quality → Material

El contrato funcional privado se describe en
[material-quality-internal.openapi.json](../api/material-quality-internal.openapi.json),
bajo `/internal/v1/quality`.

Estas rutas no se publican mediante el wildcard `/api/v1/materials`
del Gateway. La restricción de red complementa la autorización; no
sustituye la comprobación de identidad y permisos.

S3-05, secciones 2, 5.6 y 6, permite un mecanismo interno explícitamente
documentado y deja la definición de credenciales entre servicios para
cuando exista un caso real. Quality → Material constituye ese caso.

El perfil específico deberá permitir:

- Identificar de forma verificable a Quality como servicio llamante.
- Autorizar por separado la consulta/descarga privada y la
  aplicación/consulta de decisiones.
- Vincular la solicitud con el actor autenticado y, cuando corresponda,
  con `operationId`.
- Impedir que un cliente externo suplante al servicio o al actor mediante
  encabezados o campos arbitrarios.
- Correlacionar las solicitudes y su auditoría entre ambos servicios.
- Aplicar los mismos controles aunque la solicitud llegue directamente
  a Material, sin pasar por el Gateway.

No se presume que un JWT de usuario autorice por sí solo una operación
interna. Su eventual reutilización o intercambio requeriría una
justificación explícita y auditada conforme a S3-05.

La propuesta anterior de aserción RS256, vigencia máxima de 60 segundos
y scopes específicos no constituye una decisión aprobada por S3-05.
Esos detalles deberán acordarse en el perfil interno correspondiente,
sin introducir un contrato de identidad paralelo.

### 6.3. Estado de las dependencias

| Dependencia | Situación documental | Consecuencia |
| --- | --- | --- |
| Contrato común de identidad S3-05 / #445 | Consensuado | Quality lo adopta como referencia |
| Login real y emisión de JWT / #441 | Implementación referenciada por S3-05; estado de ejecución no acreditado por este documento | Necesaria para habilitar los flujos reales que requieren identidad de usuario |
| Perfil específico de autorización Quality → Material | Pendiente de definición y acuerdo entre los responsables de Auth, Quality y Material | Debe resolverse antes de habilitar las rutas internas |
| Aplicación de permisos y controles de acceso de Quality | Implementación posterior | La documentación no habilita operaciones privilegiadas |

La dependencia pendiente del perfil interno queda registrada expresamente.
No requiere implementar autenticación, endpoints ni migraciones para
cerrar esta tarea documental.

### 6.4. Autorización de decisiones ya aceptadas

Se mantiene como propuesta de política de Quality, pendiente de
confirmación en el registro de aceptación:

Una decisión autorizada y aceptada duraderamente continúa procesándose
aunque el actor cierre sesión o pierda posteriormente el rol. Los
reintentos técnicos corresponden a esa operación aceptada y no representan
una nueva decisión del usuario.

La pérdida del permiso impide nuevas decisiones y consultas privadas.
Una petición abierta en la interfaz no constituye aceptación durable.

Esta política no se atribuye a S3-05. El perfil interno deberá permitir
distinguir la autorización original de la operación y la identidad del
servicio que efectúa su entrega o reconciliación.

### 6.5. Auditoría de consultas administrativas y archivos privados

Las consultas administrativas de pendientes, las lecturas de snapshots
privados y las descargas privadas deben generar evidencia de acceso.
Se registran tanto los accesos permitidos como las denegaciones y los
fallos observados por cada servicio.

Esta auditoría es distinta del historial de decisiones de moderación:
consultar o descargar no genera por sí mismo una decisión Review.

#### Eventos y recursos

| Acción | Información del recurso |
| --- | --- |
| `LIST_PRIVATE_MATERIALS` | Filtros admitidos, página, tamaño de página y cantidad de resultados devueltos; `materialId` y `versionId` son null por tratarse de una colección |
| `READ_PRIVATE_MATERIAL` | `materialId` solicitado y `revision` entregada cuando la lectura es exitosa |
| `DOWNLOAD_PRIVATE_VERSION` | `materialId` y `versionId` solicitados; versión efectiva cuando pueda resolverse |

Los identificadores solicitados no se presentan como recursos existentes
si la autorización o la búsqueda no permitió comprobar su existencia.

#### Campos mínimos

| Campo | Regla |
| --- | --- |
| `eventId` | Identificador único del evento de auditoría |
| `requestId` | Identificador de correlación propagado entre Quality y Material |
| `occurredAt` | Fecha y hora UTC generadas por el servicio que registra el evento |
| `service` | Servicio responsable del registro: Quality o Material |
| `callerService` | Servicio llamante cuando su identidad haya sido verificada; null si no corresponde o no pudo verificarse |
| `actorId` | UUID del usuario obtenido de identidad verificada; null si no pudo autenticarse |
| `actorRole` | Rol verificado utilizado para autorizar el acceso; null si no pudo verificarse |
| `action` | Acción administrativa consultada o ejecutada |
| `phase` | `REQUEST_RESULT`, `AUTHORIZATION` o `TRANSFER_RESULT`, según corresponda |
| `materialId` | Identificador del material solicitado; null para listados |
| `versionId` | Identificador de la versión solicitada o resuelta; null cuando no corresponda |
| `revision` | Revisión del snapshot entregado, cuando corresponda |
| `outcome` | `SUCCESS`, `DENIED`, `NOT_FOUND`, `ERROR` o `ABORTED` |
| `httpStatus` | Estado HTTP emitido, si llegó a emitirse |
| `reasonCode` | Código técnico sanitizado del resultado o fallo, cuando corresponda |

Cuando la identidad no pueda verificarse, no se extrae un supuesto usuario
de un token inválido para registrarlo como actor autenticado.

#### Servicio responsable

Quality registra la autorización y el resultado de la solicitud
administrativa recibida del cliente.

Material registra el resultado de las consultas y descargas privadas
atendidas por su contrato interno, incluyendo la identidad del servicio
llamante y el contexto de actor verificado mediante el mecanismo acordado.

Cada servicio es responsable de producir su evidencia. Los registros se
correlacionan mediante `requestId`, pero conservan `eventId` independientes.
Una denegación en Quality que no llegue a Material solo genera el registro
de Quality; no se inventa un acceso en Material.

El almacenamiento podrá centralizarse posteriormente sin cambiar estas
responsabilidades.

#### Descargas

Autorizar una descarga no demuestra que la transferencia haya finalizado.

Se distingue el resultado de autorización del resultado final observado
de la transferencia. Se registra finalización, error o interrupción y,
cuando se disponga del dato, la cantidad de bytes transmitidos.

Un fallo después de enviar las cabeceras HTTP puede conservar
`httpStatus=200` y tener `outcome=ERROR` o `ABORTED`. No se registra como
descarga completada únicamente por haber emitido un 200.

La evidencia de transferencia no acredita que el usuario haya abierto
o leído el documento.

Cada servicio registra el resultado del tramo que atiende. Una transferencia
completada de Material a Quality no acredita que Quality haya completado
la entrega hacia el cliente. Ambos resultados se correlacionan mediante
requestId.

#### Protección de la evidencia

No se registran tokens, contraseñas, claves, `storageKey`, URLs firmadas
ni contenido de archivos. Tampoco se copia el cuerpo completo del
snapshot o del listado.

Los registros no se exponen mediante rutas públicas ni pueden ser
modificados o eliminados por el actor mediante los endpoints de Quality.
La implementación deberá proteger su integridad y restringir su consulta
a las funciones operativas autorizadas.

Estas reglas son obligaciones para la implementación posterior.
Este PR no crea endpoints, tablas ni un sistema de auditoría operativo.

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

La estrategia propuesta para confirmar en A1 es adaptar `WITHDRAWN` a
`RETIRED` mediante una nueva migración que conserve los registros
existentes, actualizar las referencias de código y coordinar el
despliegue de los consumidores afectados.

No se editarán migraciones ya aplicadas ni se utilizará reset.
La adaptación debe conservar la condición no pública de los materiales
retirados.

El contrato nuevo expone únicamente `RETIRED`. Cualquier compatibilidad
temporal con `WITHDRAWN` queda delimitada al consumo del servicio legado
y no introduce un segundo estado público.

La migración y el despliegue corresponden a una tarea de implementación.
No se ejecutan en este PR documental.

### Quality

Los cuatro modelos aprobados se conservan. Se requieren ampliaciones para hacer efectivos los contratos:

- ModerationOperation y outbox durables, claves/huellas de idempotencia y seguimiento PENDING_APPLICATION/APPLIED/FAILED, actor, action, expectedRevision, reason, recibo y errores sanitizados.
- Evidencia inmutable del contenido revisado y vínculo de Review a la operación cuando corresponda.
- Mapear APPROVE→Review(MODERATION,ACCEPT), REJECT→Review(MODERATION,REJECT), VERIFY→Review(VERIFICATION,ACCEPT). RETIRE/REOPEN/REVOKE_VERIFICATION se auditan como acciones de operación; no forzar su significado en ReviewDecision.REJECT.
- Reportes: resolutionNote, historial de tratamiento, idempotencia de creación/actualización y garantía de un reporte abierto por usuario/material (índice único parcial para OPEN/IN_REVIEW o mecanismo transaccional equivalente).
- Mantener unique(materialId,userId) en Rating/Favorite y CHECK de score 1..5.

No se agregan columnas de publicación autoritativas a Quality ni FKs a Material/Auth. `result.status` del recibo es evidencia histórica, no estado actual para responder a búsquedas.

## 9. Trabajo posterior y límites de aprobación

Aprobar este PR acuerda contratos; no habilita endpoints. La implementación deberá entregar autenticación de usuario, el mecanismo de autorización Quality -> Material que se acuerde conforme a S3-05, migraciones, endpoints, outbox/reconciliación, conexión del Gateway e integración Web/Mobile con los escenarios de prueba definidos. Se pueden usar mocks de identidad en pruebas y UI de prototipo, claramente separados de un entorno real. Ningún mock acredita permisos de producción.

## Referencias técnicas

- [RFC 9110: semántica HTTP](https://www.rfc-editor.org/rfc/rfc9110.html).
- [RFC 8725: buenas prácticas JWT](https://www.rfc-editor.org/rfc/rfc8725.html).
- [OWASP REST Security](https://cheatsheetseries.owasp.org/cheatsheets/REST_Security_Cheat_Sheet.html).
- [Prisma: nombres de enum y mapeo](https://www.prisma.io/docs/orm/v6/prisma-schema/data-model/database-mapping).

Estas referencias fundamentan decisiones de protocolo y seguridad; no sustituyen el acuerdo del equipo sobre permisos y políticas de producto.
