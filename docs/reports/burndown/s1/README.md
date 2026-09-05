# Burndown S1

Primer snapshot guardado: 2026-09-05.
Ultimo snapshot: 2026-09-05.
Trabajo efectivo informado desde: 2026-09-04.

## Ventanas del sprint

| Equipo | Inicio | Termino |
|---|---:|---:|
| INT2 | 2026-09-02 | 2026-09-30 |
| INT4 | 2026-09-03 | 2026-10-01 |

Los graficos usan la ventana del equipo correspondiente para la linea ideal.
Las tareas con `Equipo = Compartido` quedan fuera del burndown de equipos e integrantes.

## Equipos

| Equipo | Items | Horas asignadas | Horas usadas | Horas restantes | Horas excedidas | Grafico |
|---|---:|---:|---:|---:|---:|---|
| INT2 | 48 | 31 | 3.2 | 28 | 0.2 | [ver (2026-09-02 a 2026-09-30)](charts/team-int2.svg) |
| INT4 | 38 | 80 | 6 | 74 | 0 | [ver (2026-09-03 a 2026-10-01)](charts/team-int4.svg) |

## Integrantes

| Equipo | Integrante | Items | Horas asignadas | Horas usadas | Horas restantes | Horas excedidas | Grafico |
|---|---|---:|---:|---:|---:|---:|---|
| INT2 | Ailyn Melillan | 8 | 5 | 0 | 5 | 0 | [ver (2026-09-02 a 2026-09-30)](charts/member-ailynmelillan.svg) |
| INT2 | Antonio Lara | 9 | 5 | 0 | 5 | 0 | [ver (2026-09-02 a 2026-09-30)](charts/member-alara2024uct.svg) |
| INT2 | David Villegas | 8 | 5 | 0 | 5 | 0 | [ver (2026-09-02 a 2026-09-30)](charts/member-david7985.svg) |
| INT2 | Gabriel Gutierrez | 9 | 6 | 0 | 6 | 0 | [ver (2026-09-02 a 2026-09-30)](charts/member-gabrielgutierrez1.svg) |
| INT2 | Martina Iturrieta | 7 | 5 | 3.2 | 2 | 0.2 | [ver (2026-09-02 a 2026-09-30)](charts/member-kennyaale.svg) |
| INT2 | Raul Rodriguez | 7 | 5 | 0 | 5 | 0 | [ver (2026-09-02 a 2026-09-30)](charts/member-rrodriguez2025.svg) |
| INT4 | Eduardo Escares | 9 | 20 | 0 | 20 | 0 | [ver (2026-09-03 a 2026-10-01)](charts/member-eduardoscrs.svg) |
| INT4 | Marcelo Santana | 10 | 20 | 4 | 16 | 0 | [ver (2026-09-03 a 2026-10-01)](charts/member-cchelooo.svg) |
| INT4 | Nelson Quiñinao Isla | 10 | 20 | 2 | 18 | 0 | [ver (2026-09-03 a 2026-10-01)](charts/member-anker04.svg) |
| INT4 | Yaninna Alvarez | 9 | 20 | 0 | 20 | 0 | [ver (2026-09-03 a 2026-10-01)](charts/member-yaninna137.svg) |

## Uso diario

Actualizar horas en GitHub Projects y ejecutar:

```bash
python3 tools/burndown/project_burndown.py all --sprint S1
```

Antes de regenerar `charts/`, el script copia los SVG anteriores a `charts_backup_yesterday/`.

Notas:

- Los graficos de equipo suman issues una sola vez y excluyen epicas.
- Los graficos por integrante solo cuentan issues del mismo equipo del integrante.
- Las tareas compartidas entre INT2 e INT4 no se asignan a ninguna persona en este reporte.
- Si una tarea supera sus horas asignadas, el exceso queda reflejado en horas usadas, horas excedidas y una marca roja en el grafico; las horas restantes se grafican con minimo 0.
- Si el primer snapshot cae despues del inicio del sprint, el grafico agrega una linea base visual con horas restantes iguales a horas asignadas.
- GitHub Projects no entrega historial diario; este CSV es la evidencia historica desde que se empezo a capturar.
