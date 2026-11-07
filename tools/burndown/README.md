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
python3 tools/burndown/project_burndown.py all --sprint S3
```

Eso actualiza:

```text
docs/reports/burndown/s3/snapshots.csv
docs/reports/burndown/s3/README.md
docs/reports/burndown/s3/charts/
docs/reports/burndown/s3/charts_backup_yesterday/
```

Antes de regenerar `charts/`, el script copia los SVG anteriores a
`charts_backup_yesterday/`. Si ejecutas el comando dos veces el mismo dia, no
duplica filas en el CSV; reemplaza el snapshot del dia y el backup queda con
los graficos inmediatamente anteriores a la ultima ejecucion.

El sprint por defecto es S3. Las ventanas de S1 y S3 tienen cuatro semanas;
las de S2 se extienden a cinco semanas:

| Sprint | Equipo | Inicio | Término |
|---|---|---|---|
| S1 | INT2 | 2026-09-02 | 2026-09-30 |
| S1 | INT4 | 2026-09-03 | 2026-10-01 |
| S2 | INT2 | 2026-09-30 | 2026-11-04 |
| S2 | INT4 | 2026-10-01 | 2026-11-05 |
| S3 | INT2 | 2026-11-04 | 2026-12-02 |
| S3 | INT4 | 2026-11-05 | 2026-12-03 |

S3 comienza en la fecha de cierre de S2 y conserva miércoles para INT2 y
jueves para INT4. Estas ventanas definen
el horizonte de los gráficos y el cierre de la línea ideal. Las horas
asignadas, usadas y restantes se obtienen de las tareas de GitHub Projects.

Se conservan los historiales de S1 y S2 en `docs/reports/burndown/s1/` y
`docs/reports/burndown/s2/`. Para regenerar sus gráficos sin modificar los CSV
históricos:

```bash
python3 tools/burndown/project_burndown.py render --sprint S1
python3 tools/burndown/project_burndown.py render --sprint S2
```

La fecha de captura automática usa `America/Santiago`. Para una captura
explícita del día actual se puede usar `--date AAAA-MM-DD`; no usarlo para
atribuir las horas actuales a un día pasado.

GitHub Projects no entrega historial diario. Cada sprint comienza a guardar
evidencia desde su primera captura; no se rellenan los días anteriores con
datos inventados. La primera captura de S3 es del 06-11-2026; las líneas base
del 04-11 (INT2) y 05-11 (INT4) son referencias visuales de planificación.
En la primera captura no hay gráficos anteriores de S3 que respaldar;
`charts_backup_yesterday/` se crea en la siguiente regeneración.
La captura solicita hasta 1000 items y se detiene si la respuesta es incompleta,
para evitar omitir tareas del Project.

Si necesitas probar otro rango para todos los graficos, puedes sobreescribirlo:

```bash
python3 tools/burndown/project_burndown.py all --sprint S3 --start-date 2026-11-05 --end-date 2026-12-03
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

## Distribuciones retrospectivas documentadas

Cuando existe `estimaciones/snapshots_estimados.csv` en la carpeta del sprint,
los gráficos incorporan sus filas con origen `estimacion-retrospectiva`.
Estas filas solo modifican la curva histórica, sin alterar `snapshots.csv`
ni los totales del resumen. La última captura de cada serie y los cortes
posteriores conservan los datos registrados. Los gráficos afectados indican
que incluyen una distribución retrospectiva.
