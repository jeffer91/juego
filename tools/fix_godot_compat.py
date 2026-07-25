#!/usr/bin/env python3
"""Aplica correcciones idempotentes de compatibilidad con Godot headless."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def write(relative: str, content: str) -> None:
    (ROOT / relative).write_text(content, encoding="utf-8")


def replace_all(relative: str, replacements: list[tuple[str, str]]) -> None:
    text = read(relative)
    for old, new in replacements:
        text = text.replace(old, new)
    write(relative, text)


def add_game_manager_helper(relative: str) -> None:
    text = read(relative)
    text = text.replace("GameManager.", "_game_manager().")
    if "func _game_manager() -> Variant:" not in text:
        class_position = text.find("class_name ")
        class_line_end = text.find("\n", class_position)
        helper = '\nfunc _game_manager() -> Variant:\n\treturn get_node("/root/GameManager")\n'
        text = text[: class_line_end + 1] + helper + text[class_line_end + 1 :]
    write(relative, text)


def replace_team_colors(relative: str) -> None:
    text = read(relative)
    old = '''func _get_team_color() -> Color:
\tmatch team_id:
\t\t"player":
\t\t\treturn TeamManager.get_team_color(TeamManager.Team.PLAYER)
\t\t"enemy":
\t\t\treturn TeamManager.get_team_color(TeamManager.Team.ENEMY)
\t\t_:
\t\t\treturn TeamManager.get_team_color(TeamManager.Team.NEUTRAL)
'''
    new = '''func _get_team_color() -> Color:
\tmatch team_id:
\t\t"player":
\t\t\treturn Color(0.12, 0.45, 1.0)
\t\t"enemy":
\t\t\treturn Color(1.0, 0.15, 0.12)
\t\t_:
\t\t\treturn Color(0.55, 0.55, 0.55)
'''
    write(relative, text.replace(old, new))


def main() -> None:
    main_game = "scripts/core/MainGame.gd"
    replace_all(
        main_game,
        [
            ("GameManager.current_level", 'int(_game_manager().get("current_level"))'),
            ("GameManager.get_state_name()", 'str(_game_manager().call("get_state_name"))'),
            ("GameManager.start_game(current_level)", '_game_manager().call("start_game", current_level)'),
            ("GameManager.register_victory()", '_game_manager().call("register_victory")'),
            (
                "GameManager.has_level(current_level + 1)",
                'bool(_game_manager().call("has_level", current_level + 1))',
            ),
            ("GameManager.register_defeat()", '_game_manager().call("register_defeat")'),
            (
                "GameManager.is_level_unlocked(next_level)",
                'bool(_game_manager().call("is_level_unlocked", next_level))',
            ),
        ],
    )
    text = read(main_game)
    if "func _game_manager() -> Variant:" not in text:
        marker = "var hud: GameHUD\n"
        helper = '\nfunc _game_manager() -> Variant:\n\treturn get_node("/root/GameManager")\n'
        text = text.replace(marker, marker + helper)
        write(main_game, text)

    for relative in (
        "scripts/bases/BaseSpawner.gd",
        "scripts/units/UnitGroup.gd",
        "scripts/ai/EnemyAI.gd",
    ):
        add_game_manager_helper(relative)

    replace_team_colors("scripts/bases/Base.gd")
    replace_team_colors("scripts/units/UnitGroup.gd")

    print("Correcciones de compatibilidad aplicadas.")


if __name__ == "__main__":
    main()
