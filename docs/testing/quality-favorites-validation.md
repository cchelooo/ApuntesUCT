# Validación de favoritos

Resultados obtenidos sobre la implementación preparada a partir de ApuntesUCT(2).zip, sin los otros PR pendientes. No acreditan ejecución de GitHub Actions ni despliegue en las bases del usuario.

| Comprobación | Resultado |
| --- | --- |
| Compilación Auth, Material, Quality y Gateway | Correcta |
| Quality test:ci | 6 suites, 81 pruebas aprobadas |
| Auth test:ci | 9 suites, 70 pruebas aprobadas |
| Gateway test:ci | 4 suites, 58 pruebas aprobadas |
| Quality E2E | 1 suite, 5 pruebas aprobadas |
| Gateway E2E | 4 suites, 52 pruebas aprobadas |
| Auth E2E con PostgreSQL migrado | Ejecución correcta |
| Favoritos PostgreSQL + HTTP | 17 resultados aprobados (16 subpruebas y contenedor) |
| Persistencia Quality | 9 resultados aprobados |
| Recuperación de contraseña PostgreSQL | 1 prueba aprobada |
| Lint Quality/Auth/Gateway | Sin errores |
| Pruebas de documentación API | 5 aprobadas |
| Validador documental Quality | 1216 comprobaciones aprobadas |
| Workflow YAML | Sintaxis comprobada; ejecución remota pendiente |
| Diff | Sin errores de espacios, reconociendo CRLF del repositorio |

Casos: ausencia/falsificación/expiración/mock del token; actividad y revocación; PUT 201/200; conservación de id/createdAt; material propio permitido; aislamiento entre usuarios; entradas inválidas; materiales ocultos/inexistentes; referencias eliminadas; paginación y desempate; consultas sólo a la página; PUT concurrentes; DELETE repetido; carreras PUT/DELETE; fallos de Material/Auth; Swagger y migraciones repetidas.

Las pruebas unitarias verifican además el máximo de cuatro consultas simultáneas, conservación del orden y total, página vacía sin llamadas a Material, y cancelación al agotarse el plazo global.

La integración utiliza PostgreSQL y HTTP reales. Arranca los controladores necesarios de Auth/Material y los módulos de aplicación de Quality/Gateway en puertos libres. Usa recursos LINK y no interviene MinIO; no se acredita UI, descarga de archivos ni despliegue Docker completo. Las claves, usuarios y esquemas son temporales y se eliminan al finalizar.

Repetir la verificación en la rama del usuario, registrar el commit probado y esperar los checks/revisión antes de cerrar la tarea. No se ejecutó ninguna migración sobre las bases del usuario.
