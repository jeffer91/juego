#!/usr/bin/env python3
"""Validación estática del proyecto Godot sin dependencias externas."""

from __future__ import annotations

import json
import re
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
RES_PATH_PATTERN = re.compile(r"res://[^\"'\)\]\s]+")
CLASS_NAME_PATTERN = re.compile(r"^\s*class_name\s+([A-Za-z_][A-Za-z0-9_]*)", re.MULTILINE)

errors: list[str] = []
warnings: list[str] = []


def fail(message: str) -> None:
    errors.append(message)


def warn(message: str) -> None:
    warnings.append(message)


def read_json(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        fail(f"Falta el archivo JSON: {path.relative_to(ROOT)}")
        return {}
    except json.JSONDecodeError as exc:
        fail(f"JSON inválido en {path.relative_to(ROOT)}:{exc.lineno}:{exc.colno}: {exc.msg}")
        return {}

    if not isinstance(data, dict):
        fail(f"El JSON debe contener un objeto en la raíz: {path.relative_to(ROOT)}")
        return {}
    return data


def require_keys(data: dict[str, Any], keys: tuple[str, ...], context: str) -> None:
    for key in keys:
        if key not in data:
            fail(f"Falta la clave '{key}' en {context}")


def validate_project_file() -> None:
    project_file = ROOT / "project.godot"
    if not project_file.exists():
        fail("Falta project.godot")
        return

    text = project_file.read_text(encoding="utf-8")
    main_match = re.search(r'^run/main_scene="(res://[^"]+)"', text, re.MULTILINE)
    if not main_match:
        fail("project.godot no define run/main_scene")
    else:
        validate_res_path(main_match.group(1), "project.godot")

    for match in re.finditer(r'^([A-Za-z_][A-Za-z0-9_]*)="\*(res://[^"]+)"', text, re.MULTILINE):
        validate_res_path(match.group(2), f"autoload {match.group(1)}")


def validate_res_path(resource_path: str, context: str) -> None:
    if "%" in resource_path or "{" in resource_path:
        return
    relative = resource_path.removeprefix("res://")
    if not (ROOT / relative).exists():
        fail(f"Referencia inexistente '{resource_path}' encontrada en {context}")


def validate_resource_references() -> None:
    scanned_files = list(ROOT.rglob("*.gd")) + list(ROOT.rglob("*.tscn")) + [ROOT / "project.godot"]
    for path in scanned_files:
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8")
        for resource_path in sorted(set(RES_PATH_PATTERN.findall(text))):
            validate_res_path(resource_path.rstrip(",;"), str(path.relative_to(ROOT)))


def validate_class_names() -> None:
    occurrences: dict[str, list[str]] = defaultdict(list)
    for path in ROOT.rglob("*.gd"):
        text = path.read_text(encoding="utf-8")
        for class_name in CLASS_NAME_PATTERN.findall(text):
            occurrences[class_name].append(str(path.relative_to(ROOT)))

    for class_name, files in occurrences.items():
        if len(files) > 1:
            fail(f"class_name duplicado '{class_name}' en: {', '.join(files)}")


def validate_unit_definitions() -> set[str]:
    unit_dir = ROOT / "data" / "units"
    if not unit_dir.exists():
        fail("Falta data/units")
        return set()

    unit_ids: set[str] = set()
    for path in sorted(unit_dir.glob("*.json")):
        data = read_json(path)
        if not data:
            continue
        context = str(path.relative_to(ROOT))
        require_keys(
            data,
            (
                "id",
                "group_size",
                "max_groups_per_command",
                "speed",
                "attack_power",
                "combat_radius",
                "can_capture",
            ),
            context,
        )
        unit_id = str(data.get("id", "")).strip()
        if not unit_id:
            fail(f"Unidad sin id en {context}")
        elif unit_id in unit_ids:
            fail(f"Id de unidad duplicado '{unit_id}'")
        else:
            unit_ids.add(unit_id)

        for key in ("group_size", "max_groups_per_command", "speed", "attack_power", "combat_radius"):
            value = data.get(key)
            if not isinstance(value, (int, float)) or value <= 0:
                fail(f"'{key}' debe ser mayor que cero en {context}")

    if not unit_ids:
        fail("No se encontraron definiciones de unidades")
    return unit_ids


def validate_base_definitions(unit_ids: set[str]) -> set[str]:
    base_dir = ROOT / "data" / "bases"
    if not base_dir.exists():
        fail("Falta data/bases")
        return set()

    produced_units: set[str] = set()
    for path in sorted(base_dir.glob("*.json")):
        data = read_json(path)
        if not data:
            continue
        context = str(path.relative_to(ROOT))
        require_keys(
            data,
            ("id", "produces", "spawn_interval_seconds", "max_units", "neutral_defenders_by_difficulty"),
            context,
        )
        produces = str(data.get("produces", ""))
        produced_units.add(produces)
        if produces not in unit_ids:
            fail(f"La base {context} produce una unidad inexistente: '{produces}'")

        for key in ("spawn_interval_seconds", "max_units"):
            value = data.get(key)
            if not isinstance(value, (int, float)) or value <= 0:
                fail(f"'{key}' debe ser mayor que cero en {context}")

        defenders = data.get("neutral_defenders_by_difficulty")
        if not isinstance(defenders, dict) or not defenders:
            fail(f"'neutral_defenders_by_difficulty' debe ser un objeto no vacío en {context}")
        elif any(not isinstance(value, int) or value < 0 for value in defenders.values()):
            fail(f"Los defensores deben ser enteros no negativos en {context}")

    return produced_units


def validate_levels(unit_ids: set[str], produced_units: set[str]) -> int:
    level_dir = ROOT / "data" / "levels"
    if not level_dir.exists():
        fail("Falta data/levels")
        return 0

    level_numbers: set[int] = set()
    level_count = 0

    for path in sorted(level_dir.glob("level_*.json")):
        data = read_json(path)
        if not data:
            continue
        level_count += 1
        context = str(path.relative_to(ROOT))
        require_keys(data, ("level_number", "name", "points", "routes", "bases", "settings"), context)

        number = data.get("level_number")
        if not isinstance(number, int) or number <= 0:
            fail(f"level_number debe ser un entero positivo en {context}")
        elif number in level_numbers:
            fail(f"Número de nivel duplicado: {number}")
        else:
            level_numbers.add(number)

        points = data.get("points")
        routes = data.get("routes")
        bases = data.get("bases")
        settings = data.get("settings")

        if not isinstance(points, list) or not points:
            fail(f"'points' debe ser una lista no vacía en {context}")
            continue
        if not isinstance(routes, list) or not routes:
            fail(f"'routes' debe ser una lista no vacía en {context}")
            continue
        if not isinstance(bases, list) or not bases:
            fail(f"'bases' debe ser una lista no vacía en {context}")
            continue
        if not isinstance(settings, dict):
            fail(f"'settings' debe ser un objeto en {context}")
            settings = {}

        point_ids: set[str] = set()
        for point in points:
            if not isinstance(point, dict):
                fail(f"Punto inválido en {context}")
                continue
            point_id = str(point.get("id", ""))
            if not point_id:
                fail(f"Punto sin id en {context}")
            elif point_id in point_ids:
                fail(f"Punto duplicado '{point_id}' en {context}")
            else:
                point_ids.add(point_id)
            if not isinstance(point.get("x"), (int, float)) or not isinstance(point.get("y"), (int, float)):
                fail(f"El punto '{point_id}' necesita coordenadas numéricas en {context}")

        for route in routes:
            if not isinstance(route, dict):
                fail(f"Ruta inválida en {context}")
                continue
            for endpoint in ("from", "to"):
                point_id = str(route.get(endpoint, ""))
                if point_id not in point_ids:
                    fail(f"La ruta '{route.get('id', '')}' usa el punto inexistente '{point_id}' en {context}")

        base_ids: set[str] = set()
        teams: set[str] = set()
        for base in bases:
            if not isinstance(base, dict):
                fail(f"Base inválida en {context}")
                continue
            base_id = str(base.get("id", ""))
            point_id = str(base.get("point_id", ""))
            team = str(base.get("team", ""))
            produces = str(base.get("produces", ""))

            if not base_id:
                fail(f"Base sin id en {context}")
            elif base_id in base_ids:
                fail(f"Base duplicada '{base_id}' en {context}")
            else:
                base_ids.add(base_id)

            if point_id not in point_ids:
                fail(f"La base '{base_id}' usa el punto inexistente '{point_id}' en {context}")
            if team not in {"player", "enemy", "neutral"}:
                fail(f"Equipo inválido '{team}' en la base '{base_id}' de {context}")
            teams.add(team)
            if produces not in unit_ids:
                fail(f"La base '{base_id}' produce la unidad inexistente '{produces}' en {context}")
            if produces not in produced_units:
                fail(f"No existe definición de base para la unidad '{produces}' usada en {context}")

        if "player" not in teams or "enemy" not in teams:
            fail(f"El nivel necesita al menos una base player y una enemy en {context}")

        for key in ("victory_base_id", "defeat_base_id"):
            configured_id = str(settings.get(key, ""))
            if configured_id not in base_ids:
                fail(f"'{key}' apunta a la base inexistente '{configured_id}' en {context}")

    if level_numbers and level_numbers != set(range(1, max(level_numbers) + 1)):
        fail(f"Los niveles deben ser consecutivos desde 1. Encontrados: {sorted(level_numbers)}")
    if level_count == 0:
        fail("No se encontraron niveles")
    return level_count


def main() -> int:
    validate_project_file()
    unit_ids = validate_unit_definitions()
    produced_units = validate_base_definitions(unit_ids)
    level_count = validate_levels(unit_ids, produced_units)
    validate_resource_references()
    validate_class_names()

    print("Validación del proyecto")
    print(f"- Unidades: {len(unit_ids)}")
    print(f"- Tipos de bases: {len(produced_units)}")
    print(f"- Niveles: {level_count}")

    for message in warnings:
        print(f"ADVERTENCIA: {message}")

    if errors:
        print(f"\nSe encontraron {len(errors)} error(es):", file=sys.stderr)
        for message in errors:
            print(f"- {message}", file=sys.stderr)
        return 1

    print("Resultado: proyecto válido.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
