# Burndown desde GitHub Projects

Estos scripts usan GitHub Projects como fuente oficial de horas y guardan un
snapshot diario para poder graficar burndown por equipo e integrante.

## Requisitos

- Tener `gh` instalado y autenticado con acceso al Project.
- Mantener actualizados estos campos en cada issue:
  - `Equipo`
  - `Sprint`
  - `Tipo`
  - `Assignees`
  - `Horas asignadas`
  - `Horas usadas`
  - `Horas restantes`

## Uso diario

Desde la raiz del repo:

```bash
python3 tools/burndown/project_burndown.py all --sprint S2
```

Eso actualiza:

```text
docs/reports/burndown/s2/snapshots.csv
docs/reports/burndown/s2/README.md
docs/reports/burndown/s2/charts/
docs/reports/burndown/s2/charts_backup_yesterday/
```

Antes de regenerar `charts/`, el script copia los SVG anteriores a
`charts_backup_yesterday/`. Si ejecutas el comando dos veces el mismo dia, no
duplica filas en el CSV; reemplaza el snapshot del dia y el backup queda con
los graficos inmediatamente anteriores a la ultima ejecucion.

El sprint por defecto ahora es S2. Las ventanas tienen cuatro semanas:

| Sprint | Equipo | Inicio | Término |
|---|---|---|---|
| S1 | INT2 | 2026-09-02 | 2026-09-30 |
| S1 | INT4 | 2026-09-03 | 2026-10-01 |
| S2 | INT2 | 2026-09-30 | 2026-10-28 |
| S2 | INT4 | 2026-10-01 | 2026-10-29 |

Las fechas de S2 se calculan sumando cuatro semanas al cierre de S1,
conservando miércoles para INT2 y jueves para INT4. GitHub Projects contiene
las cuatro semanas de tareas, pero no fechas oficiales de evaluación.

Se conserva el historial de S1 en `docs/reports/burndown/s1/`. Para regenerar
sus gráficos sin modificar el CSV histórico:

```bash
python3 tools/burndown/project_burndown.py render --sprint S1
```

La fecha de captura automática usa `America/Santiago`. Para una captura
explícita del día actual se puede usar `--date AAAA-MM-DD`; no usarlo para
atribuir las horas actuales a un día pasado.

GitHub Projects no entrega historial diario. S2 comienza a guardar evidencia
desde su primera captura; no se rellenan los días anteriores con datos inventados.
La captura solicita hasta 1000 items y se detiene si la respuesta es incompleta,
para evitar omitir tareas del Project.

Si necesitas probar otro rango para todos los graficos, puedes sobreescribirlo:

```bash
python3 tools/burndown/project_burndown.py all --sprint S2 --start-date 2026-10-01 --end-date 2026-10-29
```

Ese override aplica el mismo rango a ambos equipos. El comando diario sin
override conserva la ventana propia de cada equipo.

## Criterio de calculo

- Las epicas quedan fuera de los calculos.
- Los graficos de equipo suman issues una sola vez por `Equipo`.
- Los graficos por integrante solo cuentan issues del mismo `Equipo` del integrante.
- Los issues con `Equipo = Compartido` no se suman al burndown. Se dejan fuera
  porque corresponden a coordinacion/reuniones u horas que se reportan aparte.
- Si una tarea usa mas horas de las asignadas, el exceso queda en
  `Horas usadas` y `Horas excedidas`; para el burndown `Horas restantes` se
  grafica con minimo `0`.
- Si hay horas excedidas, el SVG muestra una marca roja y una etiqueta de
  exceso.
- Si el primer snapshot real cae despues del inicio del sprint, el grafico
  agrega una linea base visual con `Horas restantes = Horas asignadas`.
- GitHub Projects no entrega historial diario; `snapshots.csv` es la evidencia
  historica desde que se empieza a capturar.
