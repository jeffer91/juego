extends Node

const RouteManagerScript := preload("res://scripts/movement/RouteManager.gd")

var failures: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _run_tests()

func _check(condition: bool, description: String) -> void:
	if condition:
		print("[OK] %s" % description)
		return

	failures.append(description)
	push_error("[FALLO] %s" % description)

func _run_tests() -> void:
	print("\n=== Revisión integral funcional del proyecto ===")
	await get_tree().process_frame

	var game_manager: Variant = get_tree().root.get_node_or_null("GameManager")
	_check(game_manager != null, "Bloque 1: GameManager está cargado como autoload")
	if game_manager == null:
		_finish_tests()
		return

	_check_all_levels(game_manager)

	var main_game_scene: PackedScene = load("res://scenes/main/MainGame.tscn")
	_check(main_game_scene != null, "Bloque 1: MainGame.tscn puede cargarse")
	if main_game_scene == null:
		_finish_tests()
		return

	var game: Variant = main_game_scene.instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame

	_check(game != null and is_instance_valid(game), "Bloque 1: MainGame.tscn se instancia correctamente")
	_check(int(game.current_level) == 1, "Bloque 1: el juego inicia en el nivel 1")
	_check(int(game.bases_by_id.size()) == 5, "Bloque 3: el nivel 1 crea sus cinco bases")

	var player_base: Variant = game.bases_by_id.get("player_base")
	var enemy_base: Variant = game.bases_by_id.get("enemy_base")
	var neutral_top: Variant = game.bases_by_id.get("neutral_top")
	var neutral_bottom: Variant = game.bases_by_id.get("neutral_bottom")

	_check(
		player_base != null and enemy_base != null and neutral_top != null and neutral_bottom != null,
		"Bloque 3: las bases principales y neutrales están disponibles"
	)
	if player_base == null or enemy_base == null or neutral_top == null or neutral_bottom == null:
		game.queue_free()
		await get_tree().process_frame
		_finish_tests()
		return

	# Producción, pausa y reanudación.
	var units_before_pause: int = int(player_base.get_available_units())
	game_manager.call("pause_game")
	player_base.spawner._on_production_timer_timeout()
	_check(
		int(player_base.get_available_units()) == units_before_pause,
		"Bloque 4: la producción se detiene mientras el juego está pausado"
	)
	game_manager.call("resume_game")
	player_base.spawner._on_production_timer_timeout()
	_check(
		int(player_base.get_available_units()) == units_before_pause + 1,
		"Bloque 4: la producción se reanuda al continuar la partida"
	)

	# Un toque fuera de las rutas no debe gastar unidades.
	game._on_base_selected("player_base")
	var units_before_invalid_touch: int = int(player_base.get_available_units())
	var groups_before_invalid_touch: int = int(game._get_active_groups().size())
	var invalid_touch := InputEventScreenTouch.new()
	invalid_touch.pressed = true
	invalid_touch.position = Vector2(640, 710)
	game._unhandled_input(invalid_touch)
	_check(
		int(player_base.get_available_units()) == units_before_invalid_touch,
		"Bloque 6: un destino fuera de las rutas no consume unidades"
	)
	_check(
		int(game._get_active_groups().size()) == groups_before_invalid_touch,
		"Bloque 6: un destino inválido no crea grupos"
	)

	# Despacho por selección real de bases y movimiento hasta la captura.
	game._on_base_selected("neutral_top")
	var dispatched_groups: Array = game._get_active_groups()
	_check(not dispatched_groups.is_empty(), "Bloque 5: tocar una base de destino despacha grupos")
	for group_value in dispatched_groups:
		var dispatched_group: Variant = group_value
		_check(
			int(dispatched_group.get_unit_count()) == 5,
			"Bloque 5: cada grupo de soldados contiene cinco unidades"
		)
		_check(bool(dispatched_group.is_moving()), "Bloque 6: cada grupo despachado inicia el movimiento")
		_check(
			dispatched_group.movement_path.size() >= 2,
			"Bloque 6: cada grupo recibe una ruta con varios puntos"
		)

	await _advance_moving_groups(game, 180, 0.10)
	_check(neutral_top.get_team_id() == "player", "Bloque 8: el movimiento real termina capturando la base superior")
	_check(
		int(neutral_top.get_available_units()) >= 5,
		"Bloque 8: los supervivientes quedan almacenados en la base conquistada"
	)

	# Combate entre grupos rivales.
	var soldier_definition: Dictionary = game.route_manager.get_unit_definition("soldier")
	var combat_player: Variant = game.unit_factory.create_group(
		"player", "soldier", 5, soldier_definition, Vector2(80, 80)
	)
	var combat_enemy: Variant = game.unit_factory.create_group(
		"enemy", "soldier", 5, soldier_definition, Vector2(80, 80)
	)
	game._register_group(combat_player)
	game._register_group(combat_enemy)
	game._resolve_world_combat()
	_check(
		int(combat_player.get_unit_count()) == 4 and int(combat_enemy.get_unit_count()) == 4,
		"Bloque 7: dos grupos rivales cercanos se causan bajas"
	)
	combat_player.destroy_group()
	combat_enemy.destroy_group()
	await get_tree().process_frame

	# Dron explosivo: daño de área y autodestrucción.
	var drone_definition: Dictionary = game.route_manager.get_unit_definition("drone")
	var drone: Variant = game.unit_factory.create_group(
		"player", "drone", 1, drone_definition, Vector2(300, 80)
	)
	var drone_target: Variant = game.unit_factory.create_group(
		"enemy", "soldier", 10, soldier_definition, Vector2(300, 80)
	)
	game._register_group(drone)
	game._register_group(drone_target)
	game._explode_drone(drone)
	_check(not bool(drone.is_alive()), "Bloque 9: el dron se destruye después de explotar")
	_check(int(drone_target.get_unit_count()) == 2, "Bloque 9: la explosión aplica el daño configurado")
	drone_target.destroy_group()
	await get_tree().process_frame

	# La IA debe poder despachar unidades desde una base enemiga.
	var groups_before_ai: int = int(game._get_active_groups().size())
	game.run_enemy_ai_turn()
	var groups_after_ai: int = int(game._get_active_groups().size())
	_check(groups_after_ai > groups_before_ai, "Bloque 10: la IA enemiga envía grupos hacia un objetivo")

	# Victoria, HUD y detención de la producción.
	enemy_base.change_team("player")
	_check(
		bool(game.game_ended) and str(game_manager.call("get_state_name")) == "victory",
		"Bloque 11: conquistar la base roja activa la victoria"
	)
	_check(bool(game.hud.result_panel.visible), "Bloque 11: la victoria muestra el panel de resultado")
	_check(bool(game.hud.next_button.visible), "Bloque 12: la victoria del nivel 1 habilita el siguiente nivel")
	_check(bool(game_manager.call("is_level_unlocked", 2)), "Bloque 12: el nivel 2 queda desbloqueado")

	var units_after_victory: int = int(player_base.get_available_units())
	player_base.spawner._on_production_timer_timeout()
	_check(
		int(player_base.get_available_units()) == units_after_victory,
		"Bloque 4: las bases dejan de producir al finalizar la partida"
	)

	# Se usa el mismo flujo del botón para avanzar al nivel 2.
	game.hud._on_next_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(int(game.current_level) == 2, "Bloque 12: el botón siguiente carga el nivel 2")
	_check(int(game.bases_by_id.size()) == 7, "Bloque 12: el nivel 2 crea sus siete bases")
	_check(not bool(game.game_ended), "Bloque 12: el nivel 2 inicia en estado jugable")

	var level_two_groups_before_ai: int = int(game._get_active_groups().size())
	game.run_enemy_ai_turn()
	_check(
		int(game._get_active_groups().size()) > level_two_groups_before_ai,
		"Bloque 10: la IA también funciona dentro del nivel 2"
	)

	# Derrota y reinicio mediante el flujo del botón.
	var level_two_player_base: Variant = game.bases_by_id.get("player_base")
	_check(level_two_player_base != null, "Bloque 11: la base azul existe en el nivel 2")
	if level_two_player_base != null:
		level_two_player_base.change_team("enemy")
	_check(
		level_two_player_base != null and bool(game.game_ended) and str(game_manager.call("get_state_name")) == "defeat",
		"Bloque 11: perder la base azul activa la derrota"
	)
	_check(bool(game.hud.result_panel.visible), "Bloque 11: la derrota muestra el panel de resultado")
	_check(not bool(game.hud.next_button.visible), "Bloque 11: la derrota no permite avanzar de nivel")

	game.hud._on_restart_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(int(game.current_level) == 2, "Bloque 11: reintentar conserva el nivel actual")
	_check(not bool(game.game_ended), "Bloque 11: reintentar devuelve el juego al estado activo")
	_check(str(game_manager.call("get_state_name")) == "playing", "Bloque 11: reintentar restaura el estado playing")
	_check(not bool(game.hud.result_panel.visible), "Bloque 11: reintentar oculta el panel de resultado")
	_check(int(game.bases_by_id.size()) == 7, "Bloque 12: el reinicio reconstruye correctamente el nivel 2")

	game.queue_free()
	await get_tree().process_frame
	_finish_tests()

func _check_all_levels(game_manager: Variant) -> void:
	var available_levels: int = int(game_manager.call("get_available_level_count"))
	_check(available_levels >= 2, "Bloque 12: existen al menos dos niveles consecutivos")

	for level_number in range(1, available_levels + 1):
		var level_manager: Variant = RouteManagerScript.new()
		_check(bool(level_manager.setup_level(level_number)), "Nivel %d: el contenido puede cargarse" % level_number)
		if level_manager.route_points.is_empty():
			continue

		var origin_numeric: int = int(level_manager.point_numeric_ids.get("player_base", 0))
		_check(origin_numeric > 0, "Nivel %d: existe el punto player_base" % level_number)
		if origin_numeric <= 0:
			continue

		for base_value in level_manager.get_base_points():
			var base_data: Dictionary = base_value
			var point_id := str(base_data.get("point_id", ""))
			var target_numeric: int = int(level_manager.point_numeric_ids.get(point_id, 0))
			var id_path: PackedInt64Array = level_manager.astar.get_id_path(origin_numeric, target_numeric)
			_check(
				target_numeric > 0 and not id_path.is_empty(),
				"Nivel %d: la base %s está conectada al grafo" % [level_number, str(base_data.get("id", ""))]
			)

		for segment_value in level_manager.get_segment_positions():
			var segment: Dictionary = segment_value
			var midpoint: Vector2 = (segment["from_position"] + segment["to_position"]) * 0.5
			_check(
				bool(level_manager.is_point_on_route(midpoint, 0.5)),
				"Nivel %d: la ruta %s reconoce correctamente su tramo" % [level_number, str(segment.get("id", ""))]
			)

func _advance_moving_groups(game: Variant, max_steps: int, delta: float) -> void:
	for _step in range(max_steps):
		var moving_groups := 0
		for group_value in game._get_active_groups():
			var group: Variant = group_value
			if bool(group.is_moving()):
				moving_groups += 1
				group._process(delta)

		await get_tree().process_frame
		if moving_groups == 0:
			return

	_check(false, "Bloque 6: los grupos concluyen el movimiento dentro del tiempo esperado")

func _finish_tests() -> void:
	if failures.is_empty():
		print("=== RESULTADO: la revisión integral terminó sin errores ===\n")
		get_tree().quit(0)
		return

	printerr("=== RESULTADO: %d verificación(es) fallaron ===" % failures.size())
	for failure in failures:
		printerr("- %s" % failure)
	get_tree().quit(1)
