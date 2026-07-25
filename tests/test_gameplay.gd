extends SceneTree

const RouteManagerScript := preload("res://scripts/movement/RouteManager.gd")
const MainGameScene := preload("res://scenes/main/MainGame.tscn")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run_tests")

func _check(condition: bool, description: String) -> void:
	if condition:
		print("[OK] %s" % description)
		return

	failures.append(description)
	push_error("[FALLO] %s" % description)

func _run_tests() -> void:
	print("\n=== Verificación integral de los bloques 1 al 12 ===")
	await process_frame

	# Bloques 1 y 2: proyecto, niveles, mapa y rutas.
	var route_manager = RouteManagerScript.new()
	_check(route_manager.setup_level(1), "Bloque 1: el proyecto puede cargar el nivel inicial")
	_check(route_manager.get_base_points().size() == 5, "Bloque 2: el nivel 1 contiene las cinco bases previstas")
	var graph_path: Array = route_manager.build_graph_path(
		route_manager.get_point("player_base"),
		route_manager.get_point("enemy_base")
	)
	_check(graph_path.size() >= 3, "Bloque 2: AStar2D genera una ruta completa entre las bases principales")

	var level_two_manager = RouteManagerScript.new()
	_check(level_two_manager.setup_level(2), "Bloque 12: el nivel 2 existe y puede cargarse")
	_check(level_two_manager.get_base_points().size() == 7, "Bloque 12: el nivel 2 contiene siete bases")

	# Instancia real de la escena principal.
	var game = MainGameScene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	_check(game != null and is_instance_valid(game), "Bloque 1: MainGame.tscn se instancia correctamente")
	_check(game.bases_by_id.size() == 5, "Bloque 3: las bases reutilizables se crean dentro del juego")

	var player_base = game.bases_by_id.get("player_base")
	var enemy_base = game.bases_by_id.get("enemy_base")
	var neutral_top = game.bases_by_id.get("neutral_top")
	var neutral_bottom = game.bases_by_id.get("neutral_bottom")

	_check(player_base != null and enemy_base != null, "Bloque 3: las bases principales están disponibles")

	# Bloque 4: producción automática y contador único.
	var units_before: int = int(player_base.get_available_units())
	player_base.spawner._on_production_timer_timeout()
	var units_after: int = int(player_base.get_available_units())
	_check(units_after == units_before + 1, "Bloque 4: una base activa produce y actualiza su cantidad de unidades")

	# Bloques 5 y 6: grupos de soldados y movimiento.
	var groups_before: int = int(game._get_active_groups().size())
	var dispatched: bool = game._dispatch_from_base(player_base, neutral_top.position, neutral_top.base_id)
	var dispatched_groups: Array = game._get_active_groups()
	_check(dispatched and dispatched_groups.size() > groups_before, "Bloque 5: la base crea grupos reales de soldados")

	var first_group = dispatched_groups[groups_before] if dispatched_groups.size() > groups_before else null
	_check(first_group != null and first_group.get_unit_type() == "soldier", "Bloque 5: el grupo creado es de tipo soldier")
	_check(first_group != null and first_group.get_unit_count() == 5, "Bloque 5: los soldados salen en grupos de cinco")
	_check(first_group != null and first_group.is_moving(), "Bloque 6: el grupo inicia el movimiento al recibir una orden")
	_check(first_group != null and first_group.movement_path.size() >= 2, "Bloque 6: el grupo recibe una ruta válida con varios puntos")

	# Bloque 7: combate automático entre soldados rivales.
	var soldier_definition: Dictionary = game.route_manager.get_unit_definition("soldier")
	var combat_player = game.unit_factory.create_group("player", "soldier", 5, soldier_definition, Vector2(80, 80))
	var combat_enemy = game.unit_factory.create_group("enemy", "soldier", 5, soldier_definition, Vector2(80, 80))
	game._register_group(combat_player)
	game._register_group(combat_enemy)
	game._resolve_world_combat()
	_check(combat_player.get_unit_count() == 4 and combat_enemy.get_unit_count() == 4, "Bloque 7: dos grupos rivales cercanos se causan bajas")

	# Bloque 8: captura de una base neutral mediante un asalto real.
	var assault_count: int = neutral_bottom.get_defense_units() + 5
	var assault_group = game.unit_factory.create_group(
		"player",
		"soldier",
		assault_count,
		soldier_definition,
		neutral_bottom.position
	)
	game._register_group(assault_group)
	game._resolve_base_assault(assault_group, neutral_bottom)
	_check(neutral_bottom.get_team_id() == "player", "Bloque 8: una fuerza superior conquista una base neutral")
	_check(neutral_bottom.get_available_units() > 0, "Bloque 8: los supervivientes quedan almacenados en la base conquistada")

	# Bloque 9: dron explosivo con daño de área y autodestrucción.
	var drone_definition: Dictionary = game.route_manager.get_unit_definition("drone")
	var drone = game.unit_factory.create_group("player", "drone", 1, drone_definition, Vector2(300, 80))
	var drone_target = game.unit_factory.create_group("enemy", "soldier", 10, soldier_definition, Vector2(300, 80))
	game._register_group(drone)
	game._register_group(drone_target)
	game._explode_drone(drone)
	_check(not drone.is_alive(), "Bloque 9: el dron se destruye después de explotar")
	_check(drone_target.get_unit_count() == 2, "Bloque 9: la explosión causa el daño de área configurado")

	# Bloque 10: la IA elige una base enemiga y despacha unidades.
	var groups_before_ai: int = int(game._get_active_groups().size())
	game.run_enemy_ai_turn()
	var groups_after_ai: int = int(game._get_active_groups().size())
	_check(groups_after_ai > groups_before_ai, "Bloque 10: la IA enemiga envía grupos hacia un objetivo")

	# Bloques 11 y 12: victoria, derrota, desbloqueo y persistencia de progreso.
	enemy_base.change_team("player")
	_check(game.game_ended and GameManager.get_state_name() == "victory", "Bloque 11: conquistar la base roja activa la victoria")
	_check(GameManager.is_level_unlocked(2), "Bloque 12: la victoria del nivel 1 desbloquea el nivel 2")

	game._load_level(1)
	await process_frame
	await process_frame
	var restarted_player_base = game.bases_by_id.get("player_base")
	restarted_player_base.change_team("enemy")
	_check(game.game_ended and GameManager.get_state_name() == "defeat", "Bloque 11: perder la base azul activa la derrota")

	game.queue_free()
	await process_frame

	if failures.is_empty():
		print("=== RESULTADO: los 12 bloques superaron la verificación integral ===\n")
		quit(0)
	else:
		printerr("=== RESULTADO: %d verificación(es) fallaron ===" % failures.size())
		for failure in failures:
			printerr("- %s" % failure)
		quit(1)
