# Distribución estimada de Anker — Sprint 2

Estimación retrospectiva preparada el 03-11-2026 a petición de Marcelo. No es un registro diario observado de trabajo.

El receso informado fue del 12 al 18 de octubre. La distribución comienza el 19. Se conserva como base el último aumento registrado: 7 horas usadas al 18-10. El total objetivo es el capturado de Projects el 03-11 y asignado por petición al corte del 02-11: 17 usadas y 3 restantes.

| Fecha | Horas del día estimadas | Usadas acumuladas estimadas | Restantes estimadas |
|---|---:|---:|---:|
| 2026-10-19 | 2 | 9 | 11 |
| 2026-10-20 | 1 | 10 | 10 |
| 2026-10-21 | 0 | 10 | 10 |
| 2026-10-22 | 1 | 11 | 9 |
| 2026-10-23 | 0 | 11 | 9 |
| 2026-10-24 | 0 | 11 | 9 |
| 2026-10-25 | 1 | 12 | 8 |
| 2026-10-26 | 0 | 12 | 8 |
| 2026-10-27 | 2 | 14 | 6 |
| 2026-10-28 | 0 | 14 | 6 |
| 2026-10-29 | 1 | 15 | 5 |
| 2026-10-30 | 0 | 15 | 5 |
| 2026-10-31 | 1 | 16 | 4 |
| 2026-11-01 | 1 | 17 | 3 |
| 2026-11-02 | 0 | 17 | 3 |

Las horas de cada día son una distribución supuesta, con jornadas de 0, 1 y 2 horas. Solo la base y el total final proceden de capturas. No se han modificado las horas de GitHub Projects ni las filas históricas de `../snapshots.csv`.

## Archivos y cálculo

- `distribucion-anker04.csv` contiene la asignación diaria estimada.
- `snapshots_estimados.csv` contiene las series derivadas de Anker e INT4, con su origen por fila.
- Los dos SVG comparan el registro original en azul con la estimación en violeta discontinua. La línea naranja conserva el ideal del sprint.

Para cada día de la curva INT4 se toma la última captura disponible del equipo, se resta la contribución registrada de Anker y se añade su contribución estimada. Los datos de los otros integrantes se mantienen en su última captura disponible, sin reconstruir su trabajo diario. Antes del 19-10 se conserva la serie registrada.

Las dos series coinciden con los totales registrados en el corte del 02-11. Son una reconstrucción limitada a ese periodo, no una captura nueva de los días intermedios.
