# Burndown S2

Primer snapshot guardado: 2026-10-03.
Ultimo snapshot: 2026-10-09.
No se reconstruyen horas de dias sin snapshot.

## Ventanas del sprint

| Equipo | Inicio | Termino |
|---|---:|---:|
| INT2 | 2026-09-30 | 2026-10-28 |
| INT4 | 2026-10-01 | 2026-10-29 |

Los graficos usan la ventana del equipo correspondiente para la linea ideal.
Las tareas con `Equipo = Compartido` quedan fuera del burndown de equipos e integrantes.

## Equipos

| Equipo | Items | Horas asignadas | Horas usadas | Horas restantes | Horas excedidas | Grafico |
|---|---:|---:|---:|---:|---:|---|
| INT2 | 50 | 120 | 24.1 | 96.5 | 0.6 | [ver (2026-09-30 a 2026-10-28)](charts/team-int2.svg) |
| INT4 | 32 | 80 | 11.5 | 68.5 | 0 | [ver (2026-10-01 a 2026-10-29)](charts/team-int4.svg) |

## Integrantes

| Equipo | Integrante | Items | Horas asignadas | Horas usadas | Horas restantes | Horas excedidas | Grafico |
|---|---|---:|---:|---:|---:|---:|---|
| INT2 | Ailyn Melillan | 9 | 20 | 5 | 15 | 0 | [ver (2026-09-30 a 2026-10-28)](charts/member-ailynmelillan.svg) |
| INT2 | Antonio Lara | 8 | 20 | 5.2 | 15 | 0.2 | [ver (2026-09-30 a 2026-10-28)](charts/member-alara2024uct.svg) |
| INT2 | David Villegas | 9 | 20 | 2 | 18 | 0 | [ver (2026-09-30 a 2026-10-28)](charts/member-david7985.svg) |
| INT2 | Gabriel Gutierrez | 8 | 20 | 4 | 16 | 0 | [ver (2026-09-30 a 2026-10-28)](charts/member-gabrielgutierrez1.svg) |
| INT2 | Martina Iturrieta | 8 | 20 | 4.9 | 15.5 | 0.4 | [ver (2026-09-30 a 2026-10-28)](charts/member-kennyaale.svg) |
| INT2 | Raul Rodriguez | 8 | 20 | 3 | 17 | 0 | [ver (2026-09-30 a 2026-10-28)](charts/member-rrodriguez2025.svg) |
| INT4 | Eduardo Escares | 8 | 20 | 0 | 20 | 0 | [ver (2026-10-01 a 2026-10-29)](charts/member-eduardoscrs.svg) |
| INT4 | Marcelo Santana | 8 | 20 | 6 | 14 | 0 | [ver (2026-10-01 a 2026-10-29)](charts/member-cchelooo.svg) |
| INT4 | Nelson Quiñinao Isla | 8 | 20 | 0 | 20 | 0 | [ver (2026-10-01 a 2026-10-29)](charts/member-anker04.svg) |
| INT4 | Yaninna Alvarez | 8 | 20 | 5.5 | 14.5 | 0 | [ver (2026-10-01 a 2026-10-29)](charts/member-yaninna137.svg) |

## Uso diario

Actualizar horas en GitHub Projects y ejecutar:

```bash
python3 tools/burndown/project_burndown.py all --sprint S2
```

Antes de regenerar `charts/`, el script copia los SVG anteriores a `charts_backup_yesterday/`.

Notas:

- Los graficos de equipo suman issues una sola vez y excluyen epicas.
- Los graficos por integrante solo cuentan issues del mismo equipo del integrante.
- Las tareas compartidas entre INT2 e INT4 no se asignan a ninguna persona en este reporte.
- Si una tarea supera sus horas asignadas, el exceso queda reflejado en horas usadas, horas excedidas y una marca roja en el grafico; las horas restantes se grafican con minimo 0.
- Si el primer snapshot cae despues del inicio del sprint, el grafico agrega una linea base visual con horas restantes iguales a horas asignadas.
- GitHub Projects no entrega historial diario; este CSV es la evidencia historica desde que se empezo a capturar.
