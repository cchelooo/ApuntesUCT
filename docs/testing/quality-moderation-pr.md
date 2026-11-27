# Implementar aprobación y rechazo durables en Quality

Quality permite a MODERATOR/ADMIN activos aprobar o rechazar materiales pendientes mediante el contrato de decisiones. Registra actor, fecha, motivo y evidencia; devuelve 202 tras confirmar operación y outbox, y expone seguimiento hasta APPLIED o FAILED. Material aplica el cambio de estado, revision y recibo en una transacción, sin acceso cruzado a bases. Los replays recuperan el resultado original y las carreras sobre una misma revisión no aplican dos decisiones.

Se incorporan lectura/descarga privada auditadas, autorización de servicio con clave separada, comprobación del rol/actividad/versionado de credencial en Auth y enrutamiento de Quality en Gateway. Las nuevas versiones vuelven a revisión. Se añaden migraciones nuevas para revision, RETIRED, recibos, operación/outbox y tokenVersion.

Validación: build/lint de cuatro servicios; 508 pruebas de sus suites test:ci; E2E de Quality, Gateway y Auth; 17 pruebas de moderación con PostgreSQL/HTTP reales; regresiones de persistencia, versiones y recuperación de contraseña; 1.217 comprobaciones documentales. Alcance y evidencias en `docs/testing/quality-moderation-validation.md`.

Revisar el perfil interno propuesto por esta implementación y el despliegue coordinado de Auth/Material/Quality. La prueba de archivos usa almacenamiento en memoria; no acredita MinIO. VERIFY/RETIRE/REOPEN y las demás funcionalidades Quality siguen fuera de este alcance.
