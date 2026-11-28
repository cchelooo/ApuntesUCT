# Identidad y disponibilidad para favoritos

Este documento describe el mecanismo incluido en el PR de favoritos, basado en el contrato de S3-05 y el Auth existente. No afirma una aprobación nueva del equipo ni un despliegue productivo.

Quality delega la validación del Bearer original al emisor mediante GET /api/v1/auth/access-context. Auth verifica firma RS256, issuer, audience, expiración y claims con AccessTokenService; consulta en su propia base la cuenta activa, el rol vigente y tokenVersion. Devuelve únicamente `{id, role, active:true}` del portador. No acepta un userId arbitrario. Quality nunca lee auth_db.

El reenvío del token a Auth tiene una razón explícita: validar la identidad del propio portador en el servicio emisor. El origen es configuración confiable, requiere HTTPS en producción y no sigue redirecciones. No se reenvía ese token a Material ni se persiste/registra en favoritos. Si Auth falla, Quality no concede acceso (503); credencial inválida/revocada devuelve 401 y cuenta inactiva 403.

Auth incorpora tokenVersion default 0, la emite en el JWT y la incrementa al recuperar contraseña. Los tokens antiguos sin claim equivalen a versión 0; tras incrementarse la versión quedan rechazados en access-context. Esto no transforma automáticamente todos los verificadores antiguos de otros servicios en validadores de revocación.

Todos los roles pueden gestionar sus propios favoritos. El userId se obtiene exclusivamente de la identidad verificada. No hay privilegio ADMIN para modificar favoritos de terceros. La API no recibe un userId de escritura ni devuelve el de persistencia.

Material sólo recibe consultas GET de detalle público por UUID. La disponibilidad se comprueba por solicitud sin caché: 200 con id correcto/PUBLISHED es true; 404 es false para la lista y NOT_FOUND para PUT. Otros errores nunca se convierten en false. Quality no modifica Material ni copia su estado autoritativo. La respuesta al cliente contiene sólo su referencia propia, fecha y disponibilidad comprobada.

DELETE no consulta Material y sigue funcionando si éste está oculto, eliminado o caído. Auth sigue siendo necesario para verificar que quien elimina es el propietario. PUT/DELETE se serializan por usuario/material dentro de Quality; la restricción única existente conserva una relación por par.

Al combinar PRs, conservar una sola implementación de access-context, tokenVersion y el proxy Quality. El módulo de favoritos no importa ni requiere ReportsModule ni el módulo de moderación pendiente.
