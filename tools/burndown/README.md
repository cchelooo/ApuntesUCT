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
python3 tools/burndown/project_burndown.py all --sprint S1
```

Eso actualiza:

```text
docs/reports/burndown/s1/snapshots.csv
docs/reports/burndown/s1/README.md
docs/reports/burndown/s1/charts/
docs/reports/burndown/s1/charts_backup_yesterday/
```

Antes de regenerar `charts/`, el script copia los SVG anteriores a
`charts_backup_yesterday/`. Si ejecutas el comando dos veces el mismo dia, no
duplica filas en el CSV; reemplaza el snapshot del dia y el backup queda con
los graficos inmediatamente anteriores a la ultima ejecucion.

Para S1 las fechas de la linea ideal ya estan configuradas:

- INT2: 2026-09-02 a 2026-09-30.
- INT4: 2026-09-03 a 2026-10-01.

El trabajo efectivo se empezo a reportar desde 2026-09-04, pero GitHub
Projects no entrega historial diario. Por eso el CSV guarda snapshots desde
que se ejecuta el script.

Si necesitas probar otro rango para todos los graficos, puedes sobreescribirlo:

```bash
python3 tools/burndown/project_burndown.py all --sprint S1 --start-date 2026-09-04 --end-date 2026-10-01
```

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
