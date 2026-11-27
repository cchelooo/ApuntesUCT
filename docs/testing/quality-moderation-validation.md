# Evidencia de validación de la implementación

Fecha: 2026-11-27. Base: ZIP ApuntesUCT(1).zip aportado por el usuario. Validación local sobre una copia extraída; no equivale a checks ejecutados en GitHub ni a un despliegue productivo.

Entorno: Linux, Node 24.22.3, Prisma 6.12.0, PostgreSQL 17.6 desechable.

| Comprobación | Resultado |
| --- | --- |
| Build de Quality, Material, Auth y Gateway | Correcto |
| Lint de los cuatro servicios | Correcto |
| Quality test:ci | 5 suites, 54 pruebas aprobadas |
| Material test:ci | 21 suites, 334 pruebas aprobadas (incluye suites HTTP según su configuración existente) |
| Auth test:ci | 8 suites, 62 pruebas aprobadas |
| Gateway test:ci | 4 suites, 58 pruebas aprobadas |
| Quality E2E | 1 suite, 5 pruebas aprobadas |
| Gateway E2E | 4 suites, 52 pruebas aprobadas |
| Auth E2E contra PostgreSQL desechable | Comando completado correctamente; se actualizó la expectativa del claim tokenVersion |
| Integración de moderación PostgreSQL + HTTP | 17 pruebas aprobadas, sin omisiones |
| Persistencia de Quality | 9 pruebas aprobadas |
| Regresión Material: persistencia, versiones y listado HTTP | 8 pruebas aprobadas |
| Recuperación de contraseña de Auth contra PostgreSQL | 1 prueba aprobada |
| Pruebas existentes de documentación API | 5 pruebas aprobadas |
| Validador documental Quality | 1.217 comprobaciones aprobadas |
| Diff | Sin errores de whitespace, reconociendo CRLF como finales de línea de Windows |

Los números de node:test incluyen el caso contenedor cuando existen subtests. No deben sumarse como escenarios funcionales independientes de las suites Jest.

La integración de moderación ejecuta controladores y servicios reales, transacciones reales, JWT RSA firmados y el proxy HTTP de Gateway. Usa un adaptador de archivos en memoria. La pérdida de respuesta se provoca después de aplicar realmente en Material. Se prueba una nueva instancia de worker recuperando una concesión vencida; no se ejecuta una prueba de reinicio del sistema operativo.

No se ejecutó toda la aplicación Web/Mobile ni una prueba nueva contra MinIO. No se ejecutaron migraciones en las bases del usuario. El workflow de GitHub se modificó para incluir estas comprobaciones, pero debe ejecutarse en el PR.

## Cambios de expectativas existentes

- La subida de una nueva versión deja el agregado pendiente de revisión; la descarga histórica pública se prueba después de volver a aprobarlo.
- RETIRED sustituye WITHDRAWN en fixtures actuales; las migraciones históricas permanecen intactas.
- Quality admite exclusivamente relaciones locales de operación/evidencia/outbox. Se mantiene la prohibición de referencias de base de datos a otros servicios.
- La prueba de despliegue compara el historial antes/después en vez de exigir exactamente una migración.
- Auth emite tokenVersion y el restablecimiento de contraseña lo incrementa.
- Gateway ya enruta Quality y su documentación/pruebas reflejan ese comportamiento.

## Revisión del equipo

El perfil de credenciales internas, la consulta de permisos actuales a Auth y la política de completar decisiones ya aceptadas deben revisarse explícitamente en el PR. La entrega no modifica las filas históricas de aceptación para inventar acuerdos ni afirma que la tarea esté aprobada por el revisor.
