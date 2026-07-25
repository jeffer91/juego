extends Node2D

const RouteManagerScript := preload("res://scripts/movement/RouteManager.gd")
const PathFinderScript := preload("res://scripts/movement/PathFinder.gd")
const BaseFactoryScript := preload("res://scripts/bases/BaseFactory.gd")
const UnitFactoryScript := preload("res://scripts/units/UnitFactory.gd")
const EnemyAIScript := preload("res://scripts/ai/EnemyAI.gd")
const GameHUDScript := preload("res://scripts/ui/GameHUD.gd")

const BACKGROUND_COLOR := Color(0.08, 0.10, 0.12)
const ROUTE_COLOR := Color(0.72, 0.72, 0.72)
const ROUTE_VALID_COLOR := Color(0.30, 0.85, 0.30, 0.16)
const ROUTE_WIDTH := 10.0
const ROUTE_VALID_WIDTH := 44.0
const BASE_TARGET_RADIUS := 70.0
const COMBAT_TICK_SECONDS := 0.60

var route_manager: RouteManager
var path_finder: PathFinder
var base_factory: BaseFactory
var unit_factory: UnitFactory

var base_container: Node2D
var unit_container: Node2D
var bases_by_id: Dictionary = {}
var unit_groups: Dictionary = {}

var selected_base_id := ""
var selected_group: UnitGroup
var current_level := 1
var combat_accumulator := 0.0
var game_ended := false

var enemy_ai: EnemyAI
var hud: GameHUD

func _ready() -> void:
	_build_game_layers()
	_build_hud()
	_build_enemy_ai()
	_load_level(maxi(1, GameManager.current_level))

func _process(delta: float) -> void:
	if game_ended or GameManager.get_state_name() != "playing":
		return

	combat_accumulator += delta
	if combat_accumulator >= COMBAT_TICK_SECONDS:
		combat_accumulator = 0.0
		_resolve_world_combat()

func _draw() -> void:
	_draw_background()
	if route_manager == null:
		return
	_draw_route_valid_areas()
	_draw_routes()

func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), BACKGROUND_COLOR, true)

func _draw_route_valid_areas() -> void:
	for segment_value in route_manager.get_segment_positions():
		var segment: Dictionary = segment_value
		draw_line(
			segment["from_position"],
			segment["to_position"],
			ROUTE_VALID_COLOR,
			ROUTE_VALID_WIDTH
		)

func _draw_routes() -> void:
	for segment_value in route_manager.get_segment_positions():
		var segment: Dictionary = segment_value
		draw_line(
			segment["from_position"],
			segment["to_position"],
			ROUTE_COLOR,
			ROUTE_WIDTH
		)

func _build_game_layers() -> void:
	base_container = Node2D.new()
	base_container.name = "Bases"
	add_child(base_container)

	unit_container = Node2D.new()
	unit_container.name = "UnitGroups"
	add_child(unit_container)

func _build_hud() -> void:
	hud = GameHUDScript.new() as GameHUD
	add_child(hud)
	hud.restart_pressed.connect(_on_restart_pressed)
	hud.next_level_pressed.connect(_on_next_level_pressed)

func _build_enemy_ai() -> void:
	enemy_ai = EnemyAIScript.new() as EnemyAI
	enemy_ai.name = "EnemyAI"
	add_child(enemy_ai)

func _load_level(level_number: int) -> void:
	game_ended = false
	combat_accumulator = 0.0
	_clear_selection()
	_clear_container(base_container)
	_clear_container(unit_container)
	bases_by_id.clear()
	unit_groups.clear()

	route_manager = RouteManagerScript.new() as RouteManager
	if not route_manager.setup_level(level_number):
		hud.set_status("No se pudo cargar el nivel %d." % level_number)
		return

	path_finder = PathFinderScript.new() as PathFinder
	path_finder.configure(route_manager)
	base_factory = BaseFactoryScript.new() as BaseFactory
	unit_factory = UnitFactoryScript.new() as UnitFactory

	current_level = level_number
	_spawn_bases()
	GameManager.start_game(current_level)

	var settings := route_manager.get_level_settings()
	var objective := str(settings.get("objective", "Conquista la base roja antes de perder la azul."))
	hud.configure_level(current_level, route_manager.get_level_name(), objective)

	var ai_interval := float(settings.get("ai_action_interval", 4.0))
	enemy_ai.configure(self, ai_interval)
	enemy_ai.start()
	queue_redraw()

func _clear_container(container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.free()

func _spawn_bases() -> void:
	for base_data_value in route_manager.get_base_points():
		var base_data: Dictionary = base_data_value
		var spawn_position := route_manager.get_point(str(base_data.get("point_id", "")))
		var base := base_factory.create_base(base_data, spawn_position)
		base.selected.connect(_on_base_selected)
		base.owner_changed.connect(_on_base_owner_changed)
		base.unit_generated.connect(_on_base_unit_generated)
		base.units_changed.connect(_on_base_units_changed)
		base_container.add_child(base)
		bases_by_id[base.base_id] = base

func _on_base_selected(base_id: String) -> void:
	if game_ended or not bases_by_id.has(base_id):
		return

	var target_base := bases_by_id[base_id] as Base

	if selected_group != null and is_instance_valid(selected_group) and selected_group.get_team_id() == "player":
		_issue_selected_group_to(target_base.position, base_id)
		return

	if not selected_base_id.is_empty() and selected_base_id != base_id and bases_by_id.has(selected_base_id):
		var source_base := bases_by_id[selected_base_id] as Base
		if source_base.get_team_id() == "player":
			if _dispatch_from_base(source_base, target_base.position, base_id):
				hud.set_status("Grupos enviados hacia %s." % base_id)
			else:
				hud.set_status("La base necesita un grupo completo para enviar unidades.")
			return

	_select_base(target_base)

func _select_base(base: Base) -> void:
	_clear_selection()
	selected_base_id = base.base_id
	base.set_selected(true)
	var summary := base.get_base_summary()
	var amount := int(summary.get("defenders", 0)) if base.is_neutral() else int(summary.get("stored_units", 0))
	hud.set_selected_text("Base %s · %s · %d" % [base.base_id, base.get_team_id(), amount])

func _on_group_selected(group_node: Node) -> void:
	if game_ended:
		return
	var group := group_node as UnitGroup
	if group == null or not group.is_alive() or group.get_team_id() != "player":
		return

	_clear_selection()
	selected_group = group
	selected_group.set_selected(true)
	hud.set_selected_text("Grupo %s · %d" % [group.get_unit_type(), group.get_unit_count()])

func _clear_selection() -> void:
	if not selected_base_id.is_empty() and bases_by_id.has(selected_base_id):
		var base := bases_by_id[selected_base_id] as Base
		if is_instance_valid(base):
			base.set_selected(false)
	selected_base_id = ""

	if selected_group != null and is_instance_valid(selected_group):
		selected_group.set_selected(false)
	selected_group = null

	if hud != null:
		hud.set_selected_text("ninguna")

func _unhandled_input(event: InputEvent) -> void:
	if game_ended or GameManager.get_state_name() != "playing":
		return

	var pressed := false
	var screen_position := Vector2.ZERO

	if event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		screen_position = event.position
	elif event is InputEventScreenTouch:
		pressed = event.pressed
		screen_position = event.position

	if not pressed:
		return

	var world_position := get_canvas_transform().affine_inverse() * screen_position
	if not path_finder.is_valid_destination(world_position):
		hud.set_status("El destino debe estar sobre una ruta válida.")
		return

	var target_base := _get_base_near_position(world_position)
	var target_base_id := ""
	if target_base != null:
		target_base_id = target_base.base_id
		world_position = target_base.position

	if selected_group != null and is_instance_valid(selected_group):
		_issue_selected_group_to(world_position, target_base_id)
	elif not selected_base_id.is_empty() and bases_by_id.has(selected_base_id):
		var source_base := bases_by_id[selected_base_id] as Base
		if not _dispatch_from_base(source_base, world_position, target_base_id):
			hud.set_status("La base necesita un grupo completo para enviar unidades.")
	else:
		hud.set_status("Primero selecciona una base azul o uno de tus grupos.")

func _issue_selected_group_to(destination: Vector2, target_base_id: String) -> void:
	if selected_group == null or not is_instance_valid(selected_group):
		return
	var path := path_finder.build_path(selected_group.position, destination)
	selected_group.move_along_path(path, target_base_id)
	hud.set_status("Grupo en movimiento.")

func _dispatch_from_base(source_base: Base, destination: Vector2, target_base_id: String) -> bool:
	if source_base == null or source_base.is_neutral() or source_base.base_id == target_base_id:
		return false

	var unit_type := source_base.get_produced_unit_type()
	var definition := route_manager.get_unit_definition(unit_type)
	if definition.is_empty():
		return false

	var group_size := maxi(1, int(definition.get("group_size", 5)))
	var available_groups := source_base.get_ready_group_count(group_size)
	if available_groups <= 0:
		return false

	var max_groups := maxi(1, int(definition.get("max_groups_per_command", available_groups)))
	var groups_to_send := mini(available_groups, max_groups)
	var consumed := source_base.consume_units(groups_to_send * group_size)
	groups_to_send = int(consumed / group_size)
	if groups_to_send <= 0:
		return false

	var path := path_finder.build_path(source_base.position, destination)
	for index in range(groups_to_send):
		var angle := TAU * float(index) / float(maxi(groups_to_send, 1))
		var offset := Vector2(cos(angle), sin(angle)) * 18.0
		var group := unit_factory.create_group(
			source_base.get_team_id(),
			unit_type,
			group_size,
			definition,
			source_base.position + offset
		)
		_register_group(group)
		group.move_along_path(path, target_base_id)

	return true

func _register_group(group: UnitGroup) -> void:
	unit_container.add_child(group)
	group.selected.connect(_on_group_selected)
	group.arrived.connect(_on_group_arrived)
	group.died.connect(_on_group_died)
	group.count_changed.connect(_on_group_count_changed)
	unit_groups[group.get_instance_id()] = group

func _on_group_arrived(group_node: Node, target_base_id: String) -> void:
	var group := group_node as UnitGroup
	if group == null or not group.is_alive() or game_ended:
		return

	if not target_base_id.is_empty() and bases_by_id.has(target_base_id):
		_resolve_base_assault(group, bases_by_id[target_base_id] as Base)
	elif group.get_team_id() == "player":
		hud.set_status("El grupo quedó defendiendo la ruta.")

func _resolve_base_assault(group: UnitGroup, target_base: Base) -> void:
	if group == null or target_base == null or not group.is_alive():
		return

	if group.get_team_id() == target_base.get_team_id():
		if group.get_unit_type() == target_base.get_produced_unit_type():
			target_base.add_units(group.get_unit_count())
			group.remove_after_transfer()
		else:
			group.position = target_base.position + Vector2(0, 58)
			group.stop_moving()
		return

	_resolve_nearby_defenders(group, target_base)
	if not group.is_alive():
		return

	var defenders := target_base.get_defense_units()
	if group.is_drone():
		var damage := group.get_assault_strength()
		target_base.apply_defense_loss(damage)
		group.destroy_group()
		if target_base.get_team_id() == "player":
			hud.set_status("Un dron enemigo dañó una base azul.")
		return

	var attackers := group.get_unit_count()
	if attackers > defenders:
		target_base.apply_defense_loss(defenders)
		var survivors := attackers - defenders
		target_base.set_owner(group.get_team_id())

		if group.get_unit_type() == target_base.get_produced_unit_type():
			target_base.add_units(survivors)
			group.remove_after_transfer()
		else:
			group.set_unit_count(survivors)
			group.position = target_base.position + Vector2(0, 58)
			group.stop_moving()
	else:
		target_base.apply_defense_loss(attackers)
		group.destroy_group()

func _resolve_nearby_defenders(attacker: UnitGroup, target_base: Base) -> void:
	var defenders := _get_groups_near(target_base.position, target_base.get_team_id(), 86.0)
	for defender in defenders:
		if not attacker.is_alive():
			return
		if defender == attacker or not defender.is_alive():
			continue

		if defender.is_drone():
			attacker.take_casualties(defender.get_attack_power())
			defender.destroy_group()
			continue

		var attacker_count := attacker.get_unit_count()
		var defender_count := defender.get_unit_count()
		if attacker_count > defender_count:
			attacker.set_unit_count(attacker_count - defender_count)
			defender.destroy_group()
		else:
			defender.set_unit_count(defender_count - attacker_count)
			attacker.destroy_group()

func _resolve_world_combat() -> void:
	var groups := _get_active_groups()

	for group in groups:
		if not group.is_alive() or not group.is_drone():
			continue
		var target := _find_enemy_group_in_range(group, group.get_combat_radius())
		if target != null:
			_explode_drone(group)

	groups = _get_active_groups()
	for first_index in range(groups.size()):
		var first := groups[first_index] as UnitGroup
		if first == null or not first.is_alive() or first.is_drone():
			continue

		for second_index in range(first_index + 1, groups.size()):
			var second := groups[second_index] as UnitGroup
			if second == null or not second.is_alive() or second.is_drone():
				continue
			if first.get_team_id() == second.get_team_id():
				continue

			var combat_distance := minf(first.get_combat_radius(), second.get_combat_radius())
			if first.position.distance_to(second.position) <= combat_distance:
				var damage_to_first := second.get_attack_power()
				var damage_to_second := first.get_attack_power()
				first.take_casualties(damage_to_first)
				second.take_casualties(damage_to_second)
				if not first.is_alive():
					break

func _explode_drone(drone: UnitGroup) -> void:
	if drone == null or not drone.is_alive():
		return

	var explosion_radius := maxf(drone.get_explosion_radius(), drone.get_combat_radius())
	for target in _get_active_groups():
		if target == drone or target.get_team_id() == drone.get_team_id():
			continue
		if drone.position.distance_to(target.position) <= explosion_radius:
			target.take_casualties(drone.get_attack_power())

	drone.destroy_group()

func _find_enemy_group_in_range(source: UnitGroup, radius: float) -> UnitGroup:
	var closest: UnitGroup
	var closest_distance := INF
	for target in _get_active_groups():
		if target == source or target.get_team_id() == source.get_team_id():
			continue
		var distance := source.position.distance_to(target.position)
		if distance <= radius and distance < closest_distance:
			closest = target
			closest_distance = distance
	return closest

func _get_active_groups() -> Array:
	var result: Array = []
	for group_value in unit_groups.values():
		var group := group_value as UnitGroup
		if group != null and is_instance_valid(group) and group.is_alive() and not group.is_queued_for_deletion():
			result.append(group)
	return result

func _get_groups_near(position: Vector2, team_id: String, radius: float) -> Array:
	var result: Array = []
	for group in _get_active_groups():
		if group.get_team_id() == team_id and group.position.distance_to(position) <= radius:
			result.append(group)
	return result

func _get_base_near_position(position: Vector2) -> Base:
	var closest: Base
	var closest_distance := BASE_TARGET_RADIUS
	for base_value in bases_by_id.values():
		var base := base_value as Base
		var distance := position.distance_to(base.position)
		if distance <= closest_distance:
			closest = base
			closest_distance = distance
	return closest

func _on_group_died(group_node: Node) -> void:
	var group := group_node as UnitGroup
	if group == null:
		return
	unit_groups.erase(group.get_instance_id())
	if selected_group == group:
		selected_group = null
		hud.set_selected_text("ninguna")

func _on_group_count_changed(group_node: Node, new_count: int) -> void:
	var group := group_node as UnitGroup
	if group != null and selected_group == group:
		hud.set_selected_text("Grupo %s · %d" % [group.get_unit_type(), new_count])

func _on_base_unit_generated(_base_id: String, _team_id: String, _unit_type: String, _total_units: int) -> void:
	pass

func _on_base_units_changed(base_id: String, total_units: int) -> void:
	if selected_base_id == base_id and bases_by_id.has(base_id):
		var base := bases_by_id[base_id] as Base
		hud.set_selected_text("Base %s · %s · %d" % [base_id, base.get_team_id(), total_units])

func _on_base_owner_changed(base_id: String, new_team_id: String) -> void:
	hud.set_status("La base %s ahora pertenece a %s." % [base_id, new_team_id])
	var settings := route_manager.get_level_settings()
	var victory_base_id := str(settings.get("victory_base_id", "enemy_base"))
	var defeat_base_id := str(settings.get("defeat_base_id", "player_base"))

	if base_id == victory_base_id and new_team_id == "player":
		_finish_game(true)
	elif base_id == defeat_base_id and new_team_id == "enemy":
		_finish_game(false)

func _finish_game(victory: bool) -> void:
	if game_ended:
		return
	game_ended = true
	enemy_ai.stop()
	_clear_selection()

	if victory:
		GameManager.register_victory()
		var has_next := GameManager.has_level(current_level + 1)
		hud.show_result(
			"Victoria",
			"Conquistaste la base enemiga y completaste el nivel %d." % current_level,
			has_next
		)
	else:
		GameManager.register_defeat()
		hud.show_result(
			"Derrota",
			"La base azul fue conquistada. Reorganiza tus grupos e inténtalo otra vez.",
			false
		)

func run_enemy_ai_turn() -> void:
	if game_ended or GameManager.get_state_name() != "playing":
		return

	var source := _choose_enemy_source_base()
	if source == null:
		return

	var target := _choose_enemy_target(source)
	if target.is_empty():
		return

	var target_position: Vector2 = target.get("position", source.position)
	_dispatch_from_base(
		source,
		target_position,
		str(target.get("base_id", ""))
	)

func _choose_enemy_source_base() -> Base:
	var best: Base
	var best_ready_groups := 0

	for base_value in bases_by_id.values():
		var base := base_value as Base
		if base.get_team_id() != "enemy":
			continue
		var definition := route_manager.get_unit_definition(base.get_produced_unit_type())
		var group_size := maxi(1, int(definition.get("group_size", 5)))
		var ready_groups := base.get_ready_group_count(group_size)
		if ready_groups > best_ready_groups:
			best = base
			best_ready_groups = ready_groups

	return best

func _choose_enemy_target(source: Base) -> Dictionary:
	var nearby_player_group := _find_nearest_group(source.position, "player", 360.0)
	if nearby_player_group != null:
		return {"position": nearby_player_group.position, "base_id": ""}

	var central_neutral := _find_central_neutral_base()
	if central_neutral != null:
		return {"position": central_neutral.position, "base_id": central_neutral.base_id}

	var neutral_target := _find_nearest_base_by_team(source.position, "neutral")
	if neutral_target != null:
		return {"position": neutral_target.position, "base_id": neutral_target.base_id}

	var player_target := _find_nearest_base_by_team(source.position, "player")
	if player_target != null:
		return {"position": player_target.position, "base_id": player_target.base_id}

	return {}

func _find_nearest_group(position: Vector2, team_id: String, max_distance: float) -> UnitGroup:
	var closest: UnitGroup
	var closest_distance := max_distance
	for group in _get_active_groups():
		if group.get_team_id() != team_id:
			continue
		var distance := position.distance_to(group.position)
		if distance < closest_distance:
			closest = group
			closest_distance = distance
	return closest

func _find_central_neutral_base() -> Base:
	for base_value in bases_by_id.values():
		var base := base_value as Base
		if base.is_neutral() and (base.base_id.contains("center") or base.get_produced_unit_type() == "drone"):
			return base
	return null

func _find_nearest_base_by_team(position: Vector2, team_id: String) -> Base:
	var closest: Base
	var closest_distance := INF
	for base_value in bases_by_id.values():
		var base := base_value as Base
		if base.get_team_id() != team_id:
			continue
		var distance := position.distance_to(base.position)
		if distance < closest_distance:
			closest = base
			closest_distance = distance
	return closest

func _on_restart_pressed() -> void:
	_load_level(current_level)

func _on_next_level_pressed() -> void:
	var next_level := current_level + 1
	if GameManager.is_level_unlocked(next_level):
		_load_level(next_level)
