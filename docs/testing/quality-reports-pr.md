# Implementar recepción y resolución de reportes en Quality

Los usuarios activos pueden reportar materiales publicados y consultar sus reportes. MODERATOR/ADMIN pueden listar y tratar reportes mediante IN_REVIEW, RESOLVED o DISMISSED, con nota obligatoria para las decisiones terminales. Resolver o crear un reporte no cambia publicación ni verificación de Material.

- Cinco rutas del contrato, validación cerrada, categorías, paginación y errores estables.
- Idempotencia con snapshots históricos, índice parcial contra abiertos duplicados y control atómico de expectedUpdatedAt.
- Historial transaccional y prohibición de tramitar reportes propios o sobre material propio, incluido ADMIN.
- Consulta REST de identidad vigente en Auth y material público en Material; sin acceso a bases ajenas.
- Migraciones nuevas de Quality y tokenVersion de Auth. Esta última coincide con la del PR de moderación pendiente: conservar una única copia al combinar ramas.
- Pruebas PostgreSQL/HTTP de éxito, autorización, concurrencia, rollback y fallos de dependencias; workflow específico.

## Validación

Ver `quality-reports-validation.md` para resultados del paquete. Antes de enviar, sustituir/complementar con comandos y resultados ejecutados en la rama local y commit probado. Los checks remotos están pendientes hasta ejecutar el PR.

## Revisión y despliegue

Revisar el perfil `../architecture/quality-reports-identity.md`. Aplicar migraciones en Auth/Quality antes de iniciar código nuevo; configurar QUALITY_REPORTS_AUTH_URL, QUALITY_REPORTS_MATERIAL_URL y QUALITY_SERVICE_URL. Conciliar reportes históricos duplicados/categorías no canónicas antes de crear restricciones. Reportes legados ocultos sin referencia de autoría requieren conciliación autorizada.

No implementa RETIRE/REOPEN, aprobación/rechazo, MinIO ni UI. La rama se construyó sobre el ZIP de main sin depender del PR anterior.
