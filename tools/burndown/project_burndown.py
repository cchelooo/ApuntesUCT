#!/usr/bin/env python3
"""Capture GitHub Projects hours and render burndown charts.

GitHub Projects stores the current value of numeric fields, not a daily
history. This script creates that history by taking one snapshot per day.
"""

from __future__ import annotations

import argparse
import csv
import html
import json
import math
import re
import shutil
import subprocess
from collections import defaultdict
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Iterable


PROJECT_OWNER = "cchelooo"
PROJECT_NUMBER = 2
DEFAULT_SPRINT = "S1"
CHART_BACKUP_DIR = "charts_backup_yesterday"
TEAM_NAMES = ("INT2", "INT4")
TEAM_WINDOWS = {
    "INT2": ("2026-09-02", "2026-09-30"),
    "INT4": ("2026-09-03", "2026-10-01"),
}
WORK_STARTED_ON = "2026-09-04"

MEMBERS = {
    "gabrielgutierrez1": {"name": "Gabriel Gutierrez", "team": "INT2"},
    "AilynMelillan": {"name": "Ailyn Melillan", "team": "INT2"},
    "KennyaAle": {"name": "Martina Iturrieta", "team": "INT2"},
    "rrodriguez2025": {"name": "Raul Rodriguez", "team": "INT2"},
    "David7985": {"name": "David Villegas", "team": "INT2"},
    "alara2024uct": {"name": "Antonio Lara", "team": "INT2"},
    "cchelooo": {"name": "Marcelo Santana", "team": "INT4"},
    "eduardoscrs": {"name": "Eduardo Escares", "team": "INT4"},
    "Yaninna137": {"name": "Yaninna Alvarez", "team": "INT4"},
    "Anker04": {"name": "Nelson Quiñinao Isla", "team": "INT4"},
}

CSV_FIELDS = [
    "snapshot_date",
    "sprint",
    "scope",
    "key",
    "name",
    "equipo",
    "items",
    "horas_asignadas",
    "horas_usadas",
    "horas_restantes",
    "horas_excedidas",
]


@dataclass
class Hours:
    assigned: float = 0.0
    used: float = 0.0
    remaining: float = 0.0
    overrun: float = 0.0
    items: float = 0.0


def normalize_key(value: str) -> str:
    return value.strip().casefold()


def item_value(item: dict, field_names: Iterable[str]):
    lookup = {normalize_key(str(key)): value for key, value in item.items()}
    for field_name in field_names:
        value = lookup.get(normalize_key(field_name))
        if value is not None:
            return value
    return None


def to_float(value, default: float | None = None) -> float | None:
    if value is None or value == "":
        return default
    if isinstance(value, (int, float)):
        return float(value)
    try:
        return float(str(value).replace(",", "."))
    except ValueError:
        return default


def issue_hours(item: dict) -> Hours:
    status = str(item_value(item, ["status"]) or "")
    assigned = to_float(
        item_value(item, ["Horas asignadas", "Horas estimadas"]), 0.0
    )
    used = to_float(item_value(item, ["Horas usadas"]), None)
    remaining = to_float(item_value(item, ["Horas restantes"]), None)

    if remaining is None and used is not None:
        remaining = (assigned or 0.0) - used
    if used is None and remaining is not None:
        used = max((assigned or 0.0) - remaining, 0.0)
    if remaining is None and status == "Done":
        remaining = 0.0
    if used is None:
        used = 0.0
    if remaining is None:
        remaining = assigned or 0.0
    overrun = max(used - (assigned or 0.0), 0.0)
    remaining = max(remaining, 0.0)

    return Hours(
        assigned=assigned or 0.0,
        used=used,
        remaining=remaining,
        overrun=overrun,
        items=1.0,
    )


def add_hours(target: Hours, source: Hours, factor: float = 1.0) -> None:
    target.assigned += source.assigned * factor
    target.used += source.used * factor
    target.remaining += source.remaining * factor
    target.overrun += source.overrun * factor
    target.items += source.items


def fetch_project(owner: str, project_number: int, limit: int) -> dict:
    command = [
        "gh",
        "project",
        "item-list",
        str(project_number),
        "--owner",
        owner,
        "--limit",
        str(limit),
        "--format",
        "json",
    ]
    result = subprocess.run(command, check=True, capture_output=True, text=True)
    return json.loads(result.stdout)


def assignee_logins(item: dict) -> list[str]:
    raw = item.get("assignees") or []
    logins: list[str] = []
    for assignee in raw:
        if isinstance(assignee, str):
            logins.append(assignee)
        elif isinstance(assignee, dict) and assignee.get("login"):
            logins.append(str(assignee["login"]))
    return logins


def project_items(payload: dict, sprint: str, include_epics: bool = False) -> list[dict]:
    items = payload.get("items", [])
    selected: list[dict] = []
    for item in items:
        if item_value(item, ["Sprint"]) != sprint:
            continue
        if not include_epics and item_value(item, ["Tipo"]) == "Epic":
            continue
        selected.append(item)
    return selected


def build_snapshot_rows(
    payload: dict,
    sprint: str,
    snapshot_date: str,
    include_shared_members: bool = False,
) -> list[dict]:
    items = project_items(payload, sprint)
    team_totals: dict[str, Hours] = {team: Hours() for team in TEAM_NAMES}
    member_totals: dict[str, Hours] = defaultdict(Hours)

    for item in items:
        equipo = item_value(item, ["Equipo"])
        hours = issue_hours(item)

        if equipo in team_totals:
            add_hours(team_totals[equipo], hours)

        counted_logins = [
            login
            for login in assignee_logins(item)
            if member_issue_should_count(login, equipo, include_shared_members)
        ]
        if not counted_logins:
            continue

        factor = 1.0 / len(counted_logins)
        for login in counted_logins:
            add_hours(member_totals[login], hours, factor=factor)

    rows: list[dict] = []
    for team in TEAM_NAMES:
        rows.append(
            snapshot_row(
                snapshot_date,
                sprint,
                "Equipo",
                team,
                team,
                team,
                team_totals[team],
            )
        )

    for login, metadata in MEMBERS.items():
        rows.append(
            snapshot_row(
                snapshot_date,
                sprint,
                "Integrante",
                login,
                metadata["name"],
                metadata["team"],
                member_totals[login],
            )
        )

    extra_members = sorted(set(member_totals) - set(MEMBERS))
    for login in extra_members:
        rows.append(
            snapshot_row(
                snapshot_date,
                sprint,
                "Integrante",
                login,
                login,
                "Sin equipo",
                member_totals[login],
            )
        )

    return rows


def member_issue_should_count(
    login: str, issue_team: str | None, include_shared_members: bool
) -> bool:
    member_team = MEMBERS.get(login, {}).get("team")
    if member_team:
        if issue_team == member_team:
            return True
        return include_shared_members and issue_team == "Compartido"
    return issue_team in TEAM_NAMES or (include_shared_members and issue_team == "Compartido")


def snapshot_row(
    snapshot_date: str,
    sprint: str,
    scope: str,
    key: str,
    name: str,
    equipo: str,
    hours: Hours,
) -> dict:
    return {
        "snapshot_date": snapshot_date,
        "sprint": sprint,
        "scope": scope,
        "key": key,
        "name": name,
        "equipo": equipo,
        "items": format_number(hours.items),
        "horas_asignadas": format_number(hours.assigned),
        "horas_usadas": format_number(hours.used),
        "horas_restantes": format_number(hours.remaining),
        "horas_excedidas": format_number(hours.overrun),
    }


def format_number(value: float) -> str:
    rounded = round(value, 2)
    if math.isclose(rounded, round(rounded)):
        return str(int(round(rounded)))
    return f"{rounded:.2f}".rstrip("0").rstrip(".")


def read_snapshot_rows(csv_path: Path) -> list[dict]:
    if not csv_path.exists():
        return []
    with csv_path.open(newline="", encoding="utf-8") as file:
        return list(csv.DictReader(file))


def write_snapshot_rows(csv_path: Path, rows: list[dict]) -> None:
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    rows.sort(key=lambda row: (row["snapshot_date"], row["scope"], row["equipo"], row["key"]))
    with csv_path.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=CSV_FIELDS)
        writer.writeheader()
        writer.writerows(rows)


def upsert_snapshot(csv_path: Path, new_rows: list[dict]) -> None:
    existing_rows = read_snapshot_rows(csv_path)
    keys = {
        (row["snapshot_date"], row["sprint"], row["scope"], row["key"])
        for row in new_rows
    }
    kept_rows = [
        row
        for row in existing_rows
        if (row["snapshot_date"], row["sprint"], row["scope"], row["key"]) not in keys
    ]
    write_snapshot_rows(csv_path, kept_rows + new_rows)


def parse_date(value: str) -> date:
    return datetime.strptime(value, "%Y-%m-%d").date()


def date_range(start: date, end: date) -> list[date]:
    if end < start:
        return [start]
    days = (end - start).days
    return [start + timedelta(days=offset) for offset in range(days + 1)]


def slug(value: str) -> str:
    normalized = re.sub(r"[^a-zA-Z0-9]+", "-", value.strip()).strip("-").lower()
    return normalized or "chart"


def render_all(
    csv_path: Path,
    output_dir: Path,
    sprint: str,
    start_date: str | None,
    end_date: str | None,
) -> None:
    rows = [row for row in read_snapshot_rows(csv_path) if row["sprint"] == sprint]
    if not rows:
        raise SystemExit(f"No hay snapshots para {sprint}. Primero ejecuta capture.")

    chart_dir = output_dir / "charts"
    backup_existing_charts(chart_dir, output_dir / CHART_BACKUP_DIR)
    chart_dir.mkdir(parents=True, exist_ok=True)

    chart_paths: list[Path] = []
    chart_windows: dict[str, tuple[date, date]] = {}
    for scope in ("Equipo", "Integrante"):
        groups = sorted(
            {row["key"] for row in rows if row["scope"] == scope},
            key=lambda key: (0 if key in TEAM_NAMES else 1, key.casefold()),
        )
        for key in groups:
            group_rows = [
                row for row in rows if row["scope"] == scope and row["key"] == key
            ]
            latest = latest_row(group_rows)
            if scope == "Integrante" and float_value(latest["horas_asignadas"]) == 0:
                continue
            chart_name = f"{'team' if scope == 'Equipo' else 'member'}-{slug(key)}.svg"
            chart_path = chart_dir / chart_name
            title = (
                f"Burndown {latest['name']} ({sprint})"
                if scope == "Integrante"
                else f"Burndown {key} ({sprint})"
            )
            first_date, last_date = chart_window(group_rows, start_date, end_date)
            chart_windows[window_key(scope, key)] = (first_date, last_date)
            render_chart(chart_path, title, group_rows, first_date, last_date)
            chart_paths.append(chart_path)

    write_summary(output_dir, sprint, rows, chart_paths, chart_windows)


def chart_window(
    rows: list[dict],
    start_date: str | None,
    end_date: str | None,
) -> tuple[date, date]:
    snapshot_dates = [parse_date(row["snapshot_date"]) for row in rows]
    team = chart_team(rows)
    configured_start, configured_end = configured_team_window(team)

    first_date = parse_date(start_date) if start_date else configured_start
    last_date = parse_date(end_date) if end_date else configured_end

    if first_date is None:
        first_date = min(snapshot_dates)
    if last_date is None:
        last_date = max(snapshot_dates)

    first_date = min(first_date, min(snapshot_dates))
    last_date = max(last_date, max(snapshot_dates))
    if last_date <= first_date:
        last_date = first_date + timedelta(days=1)

    return first_date, last_date


def chart_team(rows: list[dict]) -> str:
    latest = latest_row(rows)
    return latest["key"] if latest["scope"] == "Equipo" else latest["equipo"]


def configured_team_window(team: str) -> tuple[date | None, date | None]:
    window = TEAM_WINDOWS.get(team)
    if not window:
        return None, None
    return parse_date(window[0]), parse_date(window[1])


def window_key(scope: str, key: str) -> str:
    return f"{scope}:{key}"


def backup_existing_charts(chart_dir: Path, backup_dir: Path) -> None:
    if not chart_dir.exists():
        return

    chart_paths = sorted(chart_dir.glob("*.svg"))
    if not chart_paths:
        return

    if backup_dir.exists():
        shutil.rmtree(backup_dir)
    backup_dir.mkdir(parents=True, exist_ok=True)

    for chart_path in chart_paths:
        shutil.copy2(chart_path, backup_dir / chart_path.name)


def float_value(value: str | float | int | None) -> float:
    return to_float(value, 0.0) or 0.0


def latest_row(rows: list[dict]) -> dict:
    return sorted(rows, key=lambda row: row["snapshot_date"])[-1]


def render_chart(
    output_path: Path,
    title: str,
    rows: list[dict],
    start: date,
    end: date,
) -> None:
    actual_rows = sorted(rows, key=lambda row: row["snapshot_date"])
    actual_series = rows_with_start_baseline(actual_rows, start)
    initial = actual_series[0]
    latest = actual_series[-1]
    assigned = float_value(initial["horas_asignadas"])
    max_actual = max(float_value(row["horas_restantes"]) for row in actual_series)
    latest_overrun = float_value(latest.get("horas_excedidas"))
    y_max = max(assigned, max_actual, 1.0)
    y_max = math.ceil(y_max * 1.15)

    width, height = 960, 540
    left, right, top, bottom = 86, 34, 72, 72
    plot_width = width - left - right
    plot_height = height - top - bottom
    total_days = max((end - start).days, 1)

    def x_for(day: date) -> float:
        return left + ((day - start).days / total_days) * plot_width

    def y_for(value: float) -> float:
        return top + (1 - (value / y_max)) * plot_height

    def point(day: date, value: float) -> str:
        return f"{x_for(day):.2f},{y_for(value):.2f}"

    actual_points = [
        point(parse_date(row["snapshot_date"]), float_value(row["horas_restantes"]))
        for row in actual_series
    ]
    ideal_points = [point(start, assigned), point(end, 0)]

    grid_lines: list[str] = []
    labels: list[str] = []
    for idx in range(6):
        value = y_max * idx / 5
        y = y_for(value)
        grid_lines.append(
            f'<line x1="{left}" y1="{y:.2f}" x2="{width-right}" y2="{y:.2f}" stroke="#e5e7eb" />'
        )
        labels.append(
            f'<text x="{left-14}" y="{y+5:.2f}" text-anchor="end" class="axis">{format_number(value)}</text>'
        )

    x_ticks: list[str] = []
    tick_dates = choose_tick_dates(start, end)
    for tick in tick_dates:
        x = x_for(tick)
        x_ticks.append(
            f'<line x1="{x:.2f}" y1="{top}" x2="{x:.2f}" y2="{height-bottom}" stroke="#f3f4f6" />'
            f'<text x="{x:.2f}" y="{height-bottom+28}" text-anchor="middle" class="axis">{tick.strftime("%m/%d")}</text>'
        )

    actual_polyline = ""
    if len(actual_points) > 1:
        actual_polyline = (
            f'<polyline points="{" ".join(actual_points)}" fill="none" '
            'stroke="#2563eb" stroke-width="4" stroke-linecap="round" stroke-linejoin="round" />'
        )

    actual_markers = []
    for row in actual_series:
        day = parse_date(row["snapshot_date"])
        value = float_value(row["horas_restantes"])
        actual_markers.append(
            f'<circle cx="{x_for(day):.2f}" cy="{y_for(value):.2f}" r="5" fill="#2563eb" />'
        )

    overrun_badge = ""
    overrun_marker = ""
    if latest_overrun > 0:
        latest_day = parse_date(latest["snapshot_date"])
        latest_remaining = float_value(latest["horas_restantes"])
        marker_x = x_for(latest_day)
        marker_y = y_for(latest_remaining)
        overrun_marker = (
            f'<circle cx="{marker_x:.2f}" cy="{marker_y:.2f}" r="8" fill="#dc2626">'
            f'<title>Horas excedidas: {format_number(latest_overrun)}</title>'
            "</circle>"
        )
        overrun_badge = (
            f'<rect x="{width-right-154}" y="20" width="154" height="30" rx="6" fill="#fee2e2" />'
            f'<text x="{width-right-77}" y="40" text-anchor="middle" class="overrun">'
            f'Exceso: {format_number(latest_overrun)} h</text>'
        )

    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" role="img" aria-label="{html.escape(title)}">
  <style>
    text {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; fill: #111827; }}
    .title {{ font-size: 26px; font-weight: 700; }}
    .axis {{ font-size: 14px; fill: #4b5563; }}
    .legend {{ font-size: 15px; fill: #374151; }}
    .overrun {{ font-size: 14px; font-weight: 700; fill: #b91c1c; }}
  </style>
  <rect width="100%" height="100%" fill="#ffffff" />
  <text x="{left}" y="42" class="title">{html.escape(title)}</text>
  {overrun_badge}
  <g>{''.join(grid_lines)}</g>
  <g>{''.join(x_ticks)}</g>
  <line x1="{left}" y1="{height-bottom}" x2="{width-right}" y2="{height-bottom}" stroke="#111827" stroke-width="1.5" />
  <line x1="{left}" y1="{top}" x2="{left}" y2="{height-bottom}" stroke="#111827" stroke-width="1.5" />
  <g>{''.join(labels)}</g>
  <polyline points="{' '.join(ideal_points)}" fill="none" stroke="#f97316" stroke-width="4" stroke-linecap="round" />
  {actual_polyline}
  <g>{''.join(actual_markers)}</g>
  {overrun_marker}
  <line x1="{left}" y1="{height-28}" x2="{left+32}" y2="{height-28}" stroke="#2563eb" stroke-width="4" />
  <text x="{left+42}" y="{height-23}" class="legend">Horas restantes</text>
  <line x1="{left+220}" y1="{height-28}" x2="{left+252}" y2="{height-28}" stroke="#f97316" stroke-width="4" />
  <text x="{left+262}" y="{height-23}" class="legend">Linea ideal</text>
  <text x="{left + plot_width / 2}" y="{height-8}" text-anchor="middle" class="axis">Fecha</text>
  <text x="24" y="{top + plot_height / 2}" transform="rotate(-90 24,{top + plot_height / 2})" text-anchor="middle" class="axis">Horas</text>
</svg>
"""
    output_path.write_text(svg, encoding="utf-8")


def rows_with_start_baseline(rows: list[dict], start: date) -> list[dict]:
    first_snapshot = parse_date(rows[0]["snapshot_date"])
    if first_snapshot <= start:
        return rows

    baseline = rows[0].copy()
    baseline["snapshot_date"] = start.isoformat()
    baseline["horas_usadas"] = "0"
    baseline["horas_restantes"] = format_number(float_value(baseline["horas_asignadas"]))
    baseline["horas_excedidas"] = "0"
    return [baseline] + rows


def choose_tick_dates(start: date, end: date) -> list[date]:
    days = max((end - start).days, 1)
    if days <= 7:
        step = 1
    elif days <= 31:
        step = 7
    else:
        step = max(1, days // 5)
    ticks = [start + timedelta(days=offset) for offset in range(0, days + 1, step)]
    if ticks[-1] != end:
        ticks.append(end)
    return ticks


def write_summary(
    output_dir: Path,
    sprint: str,
    rows: list[dict],
    chart_paths: list[Path],
    chart_windows: dict[str, tuple[date, date]],
) -> None:
    del chart_paths
    latest_date = max(row["snapshot_date"] for row in rows)
    first_snapshot = min(row["snapshot_date"] for row in rows)
    latest_rows = [
        row for row in rows if row["snapshot_date"] == latest_date and row["sprint"] == sprint
    ]
    team_rows = [row for row in latest_rows if row["scope"] == "Equipo"]
    member_rows = [row for row in latest_rows if row["scope"] == "Integrante"]

    lines = [
        f"# Burndown {sprint}",
        "",
        f"Primer snapshot guardado: {first_snapshot}.",
        f"Ultimo snapshot: {latest_date}.",
        f"Trabajo efectivo informado desde: {WORK_STARTED_ON}.",
        "",
        "## Ventanas del sprint",
        "",
        "| Equipo | Inicio | Termino |",
        "|---|---:|---:|",
    ]

    for team in TEAM_NAMES:
        start, end = configured_team_window(team)
        if start is None or end is None:
            continue
        lines.append(f"| {team} | {start.isoformat()} | {end.isoformat()} |")

    lines.extend(
        [
            "",
            "Los graficos usan la ventana del equipo correspondiente para la linea ideal.",
            "Las tareas con `Equipo = Compartido` quedan fuera del burndown de equipos e integrantes.",
            "",
            "## Equipos",
            "",
            "| Equipo | Items | Horas asignadas | Horas usadas | Horas restantes | Horas excedidas | Grafico |",
            "|---|---:|---:|---:|---:|---:|---|",
        ]
    )

    for row in sorted(team_rows, key=lambda item: item["key"]):
        window = chart_windows.get(window_key("Equipo", row["key"]))
        window_label = ""
        if window:
            window_label = f" ({window[0].isoformat()} a {window[1].isoformat()})"
        chart = f"charts/team-{slug(row['key'])}.svg"
        lines.append(
            f"| {row['name']} | {row['items']} | {row['horas_asignadas']} | "
            f"{row['horas_usadas']} | {row['horas_restantes']} | "
            f"{row.get('horas_excedidas', '0')} | [ver{window_label}]({chart}) |"
        )

    lines.extend(
        [
            "",
            "## Integrantes",
            "",
            "| Equipo | Integrante | Items | Horas asignadas | Horas usadas | Horas restantes | Horas excedidas | Grafico |",
            "|---|---|---:|---:|---:|---:|---:|---|",
        ]
    )
    for row in sorted(member_rows, key=lambda item: (item["equipo"], item["name"])):
        if float_value(row["horas_asignadas"]) == 0:
            continue
        window = chart_windows.get(window_key("Integrante", row["key"]))
        window_label = ""
        if window:
            window_label = f" ({window[0].isoformat()} a {window[1].isoformat()})"
        chart = f"charts/member-{slug(row['key'])}.svg"
        lines.append(
            f"| {row['equipo']} | {row['name']} | {row['items']} | "
            f"{row['horas_asignadas']} | {row['horas_usadas']} | "
            f"{row['horas_restantes']} | {row.get('horas_excedidas', '0')} | "
            f"[ver{window_label}]({chart}) |"
        )

    lines.extend(
        [
            "",
            "## Uso diario",
            "",
            "Actualizar horas en GitHub Projects y ejecutar:",
            "",
            "```bash",
            f"python3 tools/burndown/project_burndown.py all --sprint {sprint}",
            "```",
            "",
            f"Antes de regenerar `charts/`, el script copia los SVG anteriores a `{CHART_BACKUP_DIR}/`.",
            "",
            "Notas:",
            "",
            "- Los graficos de equipo suman issues una sola vez y excluyen epicas.",
            "- Los graficos por integrante solo cuentan issues del mismo equipo del integrante.",
            "- Las tareas compartidas entre INT2 e INT4 no se asignan a ninguna persona en este reporte.",
            "- Si una tarea supera sus horas asignadas, el exceso queda reflejado en horas usadas, horas excedidas y una marca roja en el grafico; las horas restantes se grafican con minimo 0.",
            "- Si el primer snapshot cae despues del inicio del sprint, el grafico agrega una linea base visual con horas restantes iguales a horas asignadas.",
            "- GitHub Projects no entrega historial diario; este CSV es la evidencia historica desde que se empezo a capturar.",
        ]
    )

    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def output_dir_for_sprint(sprint: str) -> Path:
    return Path("docs") / "reports" / "burndown" / sprint.casefold()


def command_capture(args: argparse.Namespace) -> None:
    output_dir = Path(args.output_dir) if args.output_dir else output_dir_for_sprint(args.sprint)
    csv_path = output_dir / "snapshots.csv"
    payload = fetch_project(args.owner, args.project_number, args.limit)
    snapshot_date = args.date or date.today().isoformat()
    rows = build_snapshot_rows(payload, args.sprint, snapshot_date)
    upsert_snapshot(csv_path, rows)
    print(f"Snapshot guardado en {csv_path}")


def command_render(args: argparse.Namespace) -> None:
    output_dir = Path(args.output_dir) if args.output_dir else output_dir_for_sprint(args.sprint)
    csv_path = output_dir / "snapshots.csv"
    render_all(csv_path, output_dir, args.sprint, args.start_date, args.end_date)
    print(f"Graficos generados en {output_dir / 'charts'}")
    print(f"Resumen generado en {output_dir / 'README.md'}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Genera burndown desde GitHub Projects.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    def add_common(subparser: argparse.ArgumentParser) -> None:
        subparser.add_argument("--sprint", default=DEFAULT_SPRINT)
        subparser.add_argument("--output-dir")
        subparser.add_argument("--start-date")
        subparser.add_argument("--end-date")

    capture = subparsers.add_parser("capture", help="Captura snapshot desde GitHub Projects.")
    add_common(capture)
    capture.add_argument("--owner", default=PROJECT_OWNER)
    capture.add_argument("--project-number", type=int, default=PROJECT_NUMBER)
    capture.add_argument("--limit", type=int, default=200)
    capture.add_argument("--date")
    capture.set_defaults(func=command_capture)

    render = subparsers.add_parser("render", help="Genera graficos desde snapshots.csv.")
    add_common(render)
    render.set_defaults(func=command_render)

    all_command = subparsers.add_parser("all", help="Captura snapshot y genera graficos.")
    add_common(all_command)
    all_command.add_argument("--owner", default=PROJECT_OWNER)
    all_command.add_argument("--project-number", type=int, default=PROJECT_NUMBER)
    all_command.add_argument("--limit", type=int, default=200)
    all_command.add_argument("--date")

    def run_all(args: argparse.Namespace) -> None:
        command_capture(args)
        command_render(args)

    all_command.set_defaults(func=run_all)

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
