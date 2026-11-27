# Perfil interno v1 para moderación Quality

Estado: implementado para revisión en el PR de aprobación/rechazo. Este documento concreta la dependencia técnica dejada abierta por S3-05; no atribuye retroactivamente a #445 la aprobación de estos detalles. El despliegue debe coordinar Auth, Material y Quality.

## Identidad y permisos vigentes

El cliente conserva el JWT de Auth. Quality verifica RS256, firma, emisor, audiencia, sub UUID, iat, exp y ausencia de mock. Antes de cada solicitud privilegiada consulta `POST /internal/v1/quality/identity` de Auth mediante una aserción propia de servicio. El cuerpo contiene exclusivamente `{accessToken}` y nunca se registra.

Auth verifica el token y consulta únicamente su propia base: usuario existente, cuenta activa, `tokenVersion` coincidente y rol actual. Responde `{id,role,active:true}`. Cuenta inactiva: 403; token inválido/revocado: 401; dependencia no disponible: 503. Quality comprueba MODERATOR/ADMIN sobre el rol actual. Una aserción interna inválida no debe interpretarse como un JWT inválido del usuario: Quality responde 503.

`User.tokenVersion` inicia en 0. Los JWT emitidos incluyen ese valor; tokens previos sin el claim equivalen a 0. Restablecer la contraseña incrementa la versión en la misma transacción. Una operación administrativa futura de revocación puede incrementarla desde Auth. Esta comprobación está implementada en el flujo de Quality; los demás verificadores existentes no incorporan automáticamente revocación inmediata.

## Credencial del servicio

Quality firma con una clave RSA independiente de Auth. Auth y Material reciben únicamente su clave pública. No se admite reutilizar el JWT del usuario como credencial de Material ni confiar en x-user-id/x-role.

| Campo | Regla |
| --- | --- |
| alg | RS256; claves RSA de al menos 2048 bits |
| iss / sub | `quality-service` |
| aud | `auth-service` o `material-service`, según destino |
| iat / exp | Enteros; vigencia positiva máxima de 60 segundos; expiración validada sin tolerancia adicional |
| jti | UUID nuevo por intento técnico |
| actorId / actorRole | Identidad verificada; Material exige MODERATOR o ADMIN |
| authorizedAt | Momento de autorización; para aplicar decisiones es el momento original conservado en Quality |
| resource | Ruta absoluta y query exactas del destino |
| bodyHash | SHA-256 del JSON canónico: propiedades ordenadas recursivamente; arrays conservan orden; GET usa null |
| operationId | Obligatorio y coincidente con la ruta al aplicar o consultar un recibo |
| scope | `auth:identity:read`, `material:review:read` o `material:quality:apply` |

La expiración de una aserción de servicio no cancela una decisión. Cada reintento utiliza otra aserción corta con el mismo actor, autorización original, operationId y orden. Los recibos se buscan antes de comprobar revisión/transición. Una orden repetida con otro contenido devuelve 409.

Las lecturas privadas requieren autorización actual a través de Quality. La entrega automática conserva la autorización de una decisión duraderamente aceptada, conforme a la política A5 descrita por el contrato. El perfil y A5 deben formar parte de la revisión de esta implementación.

## Rutas y transporte

Las rutas internas están excluidas del prefijo global `/api/v1`; no se registran en el Gateway y se excluyen del Swagger público de Material/Auth. Restringir también su acceso por red. En producción, Quality exige orígenes internos HTTPS. Los orígenes son configuración del operador, nunca datos del cliente. No se siguen redirecciones.

Configurar claves sin valores predeterminados, mediante secretos del entorno. No subir PEM privados ni `.env` al repositorio. Rotar las claves mediante despliegue coordinado; esta primera implementación admite una clave pública de Quality por servicio, sin rotación simultánea de varias claves.

`QUALITY_MODERATION_ENABLED=false` por defecto. Con true, Quality valida la presencia de claves, issuer/audience y orígenes. `QUALITY_WORKER_ENABLED=false` se reserva para pruebas controladas; no concede permisos y deja las operaciones aceptadas pendientes.

## Persistencia, entrega y recuperación

Quality confirma operación, Review y outbox en una transacción. Clave única `(actorId,operationFamily,idempotencyKey)`. La huella normaliza reason y es independiente del orden JSON. Los datos de la decisión no se modifican; solo evolucionan seguimiento y resultado.

Material serializa por `(quality-service,operationId)` mediante bloqueo transaccional, y bloquea el agregado antes de aplicar. Estado, verified=false, revision y recibo se confirman juntos. Se guardan también rechazos definitivos para que otra entrega incierta no produzca un resultado contradictorio. Consultar un recibo inexistente no acredita rollback; repetir el PUT converge al resultado durable.

El worker reclama trabajo mediante una concesión de 30 segundos con token de propiedad. Un worker que pierde esa concesión no puede sobrescribir el seguimiento. Procesa una operación por ciclo de un segundo por instancia y aplica reintentos con espera creciente hasta 60 segundos. No hay límite de intentos para fallos inciertos; se emite un evento sanitizado para operación. No es una cola de alta capacidad ni promete efectos exactamente una vez en el transporte: los efectos son idempotentes.

No hay acceso cruzado a bases. Las relaciones Review/operación/outbox son locales a Quality. El recibo y el snapshot almacenados allí son evidencia histórica, no estado público autoritativo.

## Auditoría

Se emiten eventos estructurados `ModerationAccessAudit` para consultas, snapshots y descargas, tanto en Quality como en Material. Incluyen usuario verificado, rol, recurso, fecha, resultado, servicio y correlación. La transferencia se distingue de la autorización; un cierre prematuro se registra ABORTED. El servidor solo acredita el tramo que atiende, no que el usuario leyó el archivo.

Los registros se escriben al sistema de logging de Nest. El despliegue debe enviarlos a un destino persistente con permisos restringidos; este PR no instala un colector central ni define plazos de retención. No se registran tokens, cuerpos de identidad, claves, storageKey ni contenido de archivos. Los IDs de recurso solicitados en una denegación no acreditan existencia.

## Alcance funcional

Se implementan APPROVE y REJECT, seguimiento y lecturas/descargas privadas necesarias para revisar. Las otras cuatro acciones del contrato completo aún no se implementan y se rechazan con 400; el Swagger de ejecución muestra solo APPROVE/REJECT. No se incorporan calificaciones, reportes ni favoritos.

Una versión nueva de un material publicado o pendiente incrementa revision y deja el agregado PENDING_REVIEW/verified=false. Añadir versiones a REJECTED/RETIRED devuelve 409 hasta contar con reapertura autorizada. La nueva migración renombra el valor físico WITHDRAWN a RETIRED sin borrar filas. Los consumidores deben desplegarse coordinadamente; no editar migraciones aplicadas ni ejecutar reset.
