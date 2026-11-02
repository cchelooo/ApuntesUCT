# Validación real de búsqueda — tarea #253

Fecha: 2 de noviembre de 2026 (America/Santiago).

## Entorno y alcance

- Gateway local (3000), Search (3005), Catalog (3002) y Material (3003), ejecutados desde el código del repositorio.
- PostgreSQL local de Material (5436); catálogo existente con universidad, carrera, asignatura y profesor.
- Solicitudes HTTP reales a `/api/v1/search` mediante Gateway, sin mocks.
- Los cuatro healthchecks respondieron HTTP 200.
- No había materiales publicados. Se insertaron tres materiales temporales LINK, con años 2024, 2025 y 2026, asociados al catálogo existente. Uno coincidía solo por descripción.
- No se validó la interfaz en navegador ni un despliegue remoto. Esta prueba no resuelve el problema de sincronización del borrador con el historial.

## Resultados

23 comprobaciones satisfactorias.

| Escenario | HTTP | Resultado |
| --- | --- | --- |
| Sin coincidencias antes de insertar | 200 | Correcto |
| Título y descripción reales | 200 | Correcto |
| Mayúsculas y tildes | 200 | Correcto |
| Filtro universidad | 200 | Correcto |
| Filtro carrera | 200 | Correcto |
| Filtro asignatura | 200 | Correcto |
| Filtro profesor | 200 | Correcto |
| Año | 200 | Correcto |
| Tipo | 200 | Correcto |
| Filtros combinados | 200 | Correcto |
| Filtros sin texto | 200 | Correcto |
| Sin coincidencias | 200 | Correcto |
| Año sin coincidencias | 200 | Correcto |
| Tipo sin coincidencias | 200 | Correcto |
| Página 1 | 200 | Correcto |
| Página 2 | 200 | Correcto |
| Orden año descendente | 200 | Correcto |
| Orden título ascendente | 200 | Correcto |
| Jerarquía inválida devuelve 400 | 400 | Correcto |
| Año inválido devuelve 400 | 400 | Correcto |
| Página inválida devuelve 400 | 400 | Correcto |
| Detalle de material devuelto en búsqueda | 200 | Correcto |
| Gateway coincide con Search directo | 200 | Correcto |

Se verificaron los IDs esperados, el orden de los resultados, los totales y la segunda página. Los filtros sin texto incluyeron el material esperado. El detalle devolvió el mismo ID que la búsqueda.

## Limpieza

- Materiales existentes antes: 1; después: 1.
- Eliminados exclusivamente los 3 materiales creados por la prueba, identificados por UUID y enlace temporal únicos.
- Se confirmó que no quedan esos UUID y que buscar el identificador temporal devuelve cero resultados.
- No se modificaron los registros del catálogo.

## Límites

- Datos controlados persistidos en la base real local; no demuestra rendimiento con un volumen grande ni funcionamiento en producción.
- Los errores probados corresponden a validación HTTP 400. No se provocaron caídas de dependencias ni se comprobaron visualmente loading/error.
- La suite de frontend y la comprobación de historial son validaciones separadas.
