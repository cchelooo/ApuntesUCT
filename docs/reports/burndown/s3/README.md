# Burndown S3

Primer snapshot guardado: 2026-11-06.
Ultimo snapshot: 2026-11-24.
Corte del 07-11-2026 registrado el 08-11-2026 con las horas actuales de GitHub Projects, por actualización diferida solicitada. No corresponde a una captura histórica tomada el día 7.
Corte del 09-11-2026 registrado el 10-11-2026 con las horas actuales de GitHub Projects, por actualización diferida solicitada; no es una captura histórica tomada el día 9.
Corte del 10-11-2026 registrado el 11-11-2026 con las horas actuales de GitHub Projects, por actualización diferida solicitada; no es una captura histórica tomada el día 10.
Corte del 12-11-2026 registrado el 13-11-2026 con las horas actuales de GitHub Projects, por actualización diferida solicitada; no es una captura histórica tomada el día 12.
Corte del 13-11-2026 registrado el 14-11-2026 con las horas actuales de GitHub Projects, por actualización diferida solicitada; no es una captura histórica tomada el día 13.
Corte del 16-11-2026 registrado el 17-11-2026 con las horas actuales de GitHub Projects, por actualización diferida solicitada; no es una captura histórica tomada el día 16.
Corte del 17-11-2026 registrado el 18-11-2026 con las horas actuales de GitHub Projects, por actualización diferida solicitada; no es una captura histórica tomada el día 17.
Corte del 19-11-2026 registrado el 20-11-2026 con las horas actuales de GitHub Projects, por actualización diferida solicitada; no es una captura histórica tomada el día 19.
Corte del 20-11-2026 registrado el 21-11-2026 con las horas actuales de GitHub Projects, por actualización diferida solicitada; no es una captura histórica tomada el día 20.
Corte del 24-11-2026 actualizado el 25-11-2026 con los valores actuales de
GitHub Projects. Las tablas muestran esos valores del tablero.
No se agregaron cortes para fechas sin captura.

## Ventanas del sprint

| Equipo | Inicio | Termino |
|---|---:|---:|
| INT2 | 2026-11-04 | 2026-12-02 |
| INT4 | 2026-11-05 | 2026-12-03 |

Los graficos usan la ventana del equipo correspondiente para la linea ideal.
Las tareas con `Equipo = Compartido` quedan fuera del burndown de equipos e integrantes.

## Equipos

| Equipo | Items | Horas asignadas | Horas usadas | Horas restantes | Horas excedidas | Grafico |
|---|---:|---:|---:|---:|---:|---|
| INT2 | 53 | 120 | 25 | 95 | 0 | [ver (2026-11-04 a 2026-12-02)](charts/team-int2.svg) |
| INT4 | 48 | 80 | 30 | 50 | 0 | [ver (2026-11-05 a 2026-12-03)](charts/team-int4.svg) |

## Integrantes

| Equipo | Integrante | Items | Horas asignadas | Horas usadas | Horas restantes | Horas excedidas | Grafico |
|---|---|---:|---:|---:|---:|---:|---|
| INT2 | Ailyn Melillan | 8 | 20 | 10 | 10 | 0 | [ver (2026-11-04 a 2026-12-02)](charts/member-ailynmelillan.svg) |
| INT2 | Antonio Lara | 10 | 20 | 5 | 15 | 0 | [ver (2026-11-04 a 2026-12-02)](charts/member-alara2024uct.svg) |
| INT2 | David Villegas | 9 | 20 | 5 | 15 | 0 | [ver (2026-11-04 a 2026-12-02)](charts/member-david7985.svg) |
| INT2 | Gabriel Gutierrez | 10 | 20 | 5 | 15 | 0 | [ver (2026-11-04 a 2026-12-02)](charts/member-gabrielgutierrez1.svg) |
| INT2 | Martina Iturrieta | 8 | 20 | 0 | 20 | 0 | [ver (2026-11-04 a 2026-12-02)](charts/member-kennyaale.svg) |
| INT2 | Raul Rodriguez | 8 | 20 | 0 | 20 | 0 | [ver (2026-11-04 a 2026-12-02)](charts/member-rrodriguez2025.svg) |
| INT4 | Eduardo Escares | 12 | 20 | 0 | 20 | 0 | [ver (2026-11-05 a 2026-12-03)](charts/member-eduardoscrs.svg) |
| INT4 | Marcelo Santana | 12 | 20 | 14 | 6 | 0 | [ver (2026-11-05 a 2026-12-03)](charts/member-cchelooo.svg) |
| INT4 | Nelson Quiñinao Isla | 12 | 20 | 8 | 12 | 0 | [ver (2026-11-05 a 2026-12-03)](charts/member-anker04.svg) |
| INT4 | Yaninna Alvarez | 12 | 20 | 8 | 12 | 0 | [ver (2026-11-05 a 2026-12-03)](charts/member-yaninna137.svg) |

## Distribución retrospectiva

Las curvas de Marcelo, Eduardo, Nelson e INT4 incorporan estimaciones para
los tramos con registro incompleto. Los valores originales se conservan en
`snapshots.csv`. En el gráfico de INT4, el corte del 24 muestra **36.5 horas
usadas y 43.5 restantes** al incluir **6.5 horas estimadas de Eduardo**. El
tablero muestra 30 usadas y 50 restantes para ese equipo.

La curva de Yaninna conserva el gráfico del 22-11. Sus valores al 24 siguen
siendo 8 horas usadas y 12 restantes. [Detalle y método](estimaciones/README.md).

## Uso diario

Actualizar horas en GitHub Projects y ejecutar:

```bash
python3 tools/burndown/project_burndown.py all --sprint S3
```

Antes de regenerar `charts/`, el script copia los SVG anteriores a `charts_backup_yesterday/`.

Notas:

- Los graficos de equipo suman issues una sola vez y excluyen epicas.
- Los graficos por integrante solo cuentan issues del mismo equipo del integrante.
- Las tareas compartidas entre INT2 e INT4 no se asignan a ninguna persona en este reporte.
- Si una tarea supera sus horas asignadas, el exceso queda reflejado en horas usadas, horas excedidas y una marca roja en el grafico; las horas restantes se grafican con minimo 0.
- Si el primer snapshot cae despues del inicio del sprint, el grafico agrega una linea base visual con horas restantes iguales a horas asignadas.
- GitHub Projects no entrega historial diario; este CSV es la evidencia historica desde que se empezo a capturar.
