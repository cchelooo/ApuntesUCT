# Validación de recepción y resolución de reportes

Validación realizada sobre el código preparado a partir de ApuntesUCT(2).zip. No acredita ejecución de GitHub Actions, revisión del equipo ni despliegue del usuario.

| Comprobación | Resultado |
| --- | --- |
| Compilación Auth, Material, Quality y Gateway | Correcta |
| Quality test:ci | 5 suites, 77 pruebas aprobadas |
| Auth test:ci | 9 suites, 70 pruebas aprobadas |
| Gateway test:ci | 4 suites, 58 pruebas aprobadas |
| Quality E2E | 1 suite, 5 pruebas aprobadas |
| Gateway E2E | 4 suites, 52 pruebas aprobadas |
| Auth E2E con PostgreSQL migrado | Ejecución correcta |
| Integración de reportes PostgreSQL + HTTP | 20 resultados aprobados (19 subpruebas y contenedor) |
| Persistencia de Quality | 9 resultados aprobados |
| Recuperación de contraseña con PostgreSQL | 1 prueba aprobada |
| Lint Quality/Auth/Gateway | Sin errores |
| Pruebas de documentación API | 5 aprobadas |
| Validador documental Quality | 1216 comprobaciones aprobadas |
| Revisión de espacios del diff | Correcta, reconociendo CRLF del repositorio |

Los casos nuevos incluyen autenticación y autorización, creación, visibilidad, consulta propia/ajena, resolución y descarte, autorresolución, replay histórico, aislamiento de claves por usuario, duplicados concurrentes, revisiones obsoletas, historial, rollback, rol vigente, revocación, dependencias caídas, reportes legados y migraciones repetibles. Swagger y el error de JSON malformado de Quality también se comprueban.

La integración arranca controladores reales de Auth y Material, módulos de aplicación de Quality/Gateway y bases PostgreSQL reales con esquemas desechables. Material utiliza LINK; el adaptador de almacenamiento no interviene. No se prueban MinIO, UI ni despliegue Docker completo. Las claves y cuentas son fixtures temporales, nunca credenciales productivas.

No se ejecutaron migraciones sobre las bases del usuario. Al aplicar el paquete se deben repetir las pruebas sobre su rama y registrar el commit probado. El workflow nuevo debe completar sus checks en GitHub antes del cierre.
