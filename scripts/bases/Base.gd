extends Node2D

class_name Base

signal owner_changed(base_id: String, new_team_id: String)
signal selected(base_id: String)
signal unit_generated(base_id: String, team_id: String, unit_type: String, total_units: int)
signal units_changed(base_id: String, total_units: int)

const BASE_RADIUS := 38.0
const SELECTION_RADIUS := 50.0
const MAIN_BASE_MARK_SIZE := 28.0

var base_id := ""
var point_id := ""
var team_id := "neutral"
var base_type := "soldier_base"
var produces := "soldier"
var difficulty := 0
var defenders := 0
var stored_units := 0
var is_selected := false

var count_label: Label
var spawner: BaseSpawner

func _ready() -> void:
	_prepare_count_label()
	_prepare_spawner()
	_connect_click_area()
	_update_count_label()

func setup(base_data: Dictionary, spawn_position: Vector2) -> void:
	base_id = str(base_data.get("id", "base"))
	point_id = str(base_data.get("point_id", ""))
	team_id = str(base_data.get("team", "neutral"))
	base_type = str(base_data.get("base_type", "soldier_base"))
	produces = str(base_data.get("produces", "soldier"))
	difficulty = int(base_data.get("difficulty", 0))
	defenders = maxi(0, int(base_data.get("defenders", 0)))
	stored_units = maxi(0, int(base_data.get("initial_units", 0)))

	position = spawn_position
	name = "Base_%s" % base_id

	_prepare_count_label()
	_prepare_spawner()
	if spawner != null:
		spawner.configure(base_data)
		stored_units = spawner.get_stored_units()

	_update_count_label()
	queue_redraw()

func set_owner(new_team_id: String) -> void:
	if team_id == new_team_id:
		return

	team_id = new_team_id
	defenders = 0

	if spawner != null:
		spawner.update_team(team_id)

	_update_count_label()
	owner_changed.emit(base_id, team_id)
	queue_redraw()

func set_selected(value: bool) -> void:
	is_selected = value
	queue_redraw()

func get_team_id() -> String:
	return team_id

func get_point_id() -> String:
	return point_id

func get_base_type() -> String:
	return base_type

func get_produced_unit_type() -> String:
	return produces

func get_available_units() -> int:
	return stored_units

func get_ready_group_count(group_size: int) -> int:
	if group_size <= 0:
		return 0
	return int(stored_units / group_size)

func get_defense_units() -> int:
	if team_id == "neutral":
		return defenders
	return stored_units

func add_units(amount: int) -> int:
	if spawner == null:
		return 0
	return spawner.add_units(amount)

func consume_units(amount: int) -> int:
	if spawner == null:
		return 0
	return spawner.consume_units(amount)

func apply_defense_loss(amount: int) -> int:
	if amount <= 0:
		return 0

	if team_id == "neutral":
		var removed := mini(amount, defenders)
		defenders -= removed
		_update_count_label()
		return removed

	return consume_units(amount)

func can_produce() -> bool:
	return team_id != "neutral" and not produces.is_empty()

func is_neutral() -> bool:
	return team_id == "neutral"

func is_player_base() -> bool:
	return team_id == "player"

func is_enemy_base() -> bool:
	return team_id == "enemy"

func is_main_base() -> bool:
	return base_type == "main_player" or base_type == "main_enemy"

func get_base_summary() -> Dictionary:
	return {
		"id": base_id,
		"point_id": point_id,
		"team": team_id,
		"base_type": base_type,
		"produces": produces,
		"difficulty": difficulty,
		"defenders": defenders,
		"stored_units": stored_units,
		"can_produce": can_produce()
	}

func _draw() -> void:
	_draw_body()
	_draw_type_marker()
	_draw_difficulty_marker()
	_draw_selection_marker()

func _draw_body() -> void:
	var color := _get_team_color()
	draw_circle(Vector2.ZERO, BASE_RADIUS, color)
	draw_arc(Vector2.ZERO, BASE_RADIUS + 4.0, 0.0, TAU, 64, Color.WHITE, 3.0)

func _draw_type_marker() -> void:
	if is_main_base():
		var rect := Rect2(
			Vector2(-MAIN_BASE_MARK_SIZE / 2.0, -MAIN_BASE_MARK_SIZE / 2.0),
			Vector2(MAIN_BASE_MARK_SIZE, MAIN_BASE_MARK_SIZE)
		)
		draw_rect(rect, Color.WHITE, false, 4.0)

	if produces == "drone":
		var drone_points := PackedVector2Array([
			Vector2(0, -12), Vector2(12, 0), Vector2(0, 12), Vector2(-12, 0)
		])
		draw_colored_polygon(drone_points, Color.YELLOW)

func _draw_difficulty_marker() -> void:
	if difficulty <= 0:
		return

	var start_x := -float(difficulty - 1) * 7.0
	for index in range(difficulty):
		var marker_position := Vector2(start_x + float(index) * 14.0, BASE_RADIUS + 16.0)
		draw_circle(marker_position, 4.5, Color.YELLOW)

func _draw_selection_marker() -> void:
	if not is_selected:
		return
	draw_arc(Vector2.ZERO, SELECTION_RADIUS, 0.0, TAU, 80, Color(0.25, 0.95, 1.0), 4.0)

func _prepare_count_label() -> void:
	if count_label != null:
		return

	if has_node("UnitCountLabel"):
		count_label = $UnitCountLabel
	else:
		count_label = Label.new()
		count_label.name = "UnitCountLabel"
		count_label.position = Vector2(-50, -92)
		count_label.size = Vector2(100, 24)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(count_label)

func _prepare_spawner() -> void:
	if spawner == null and has_node("Spawner"):
		spawner = $Spawner

	if spawner == null:
		return

	if not spawner.units_changed.is_connected(_on_spawner_units_changed):
		spawner.units_changed.connect(_on_spawner_units_changed)
	if not spawner.unit_generated.is_connected(_on_spawner_unit_generated):
		spawner.unit_generated.connect(_on_spawner_unit_generated)

func _connect_click_area() -> void:
	if has_node("ClickArea") and not $ClickArea.input_event.is_connected(_on_click_area_input_event):
		$ClickArea.input_event.connect(_on_click_area_input_event)

func _on_spawner_units_changed(_base_id: String, total_units: int) -> void:
	stored_units = total_units
	_update_count_label()
	units_changed.emit(base_id, stored_units)

func _on_spawner_unit_generated(_base_id: String, _team_id: String, _unit_type: String, total_units: int) -> void:
	unit_generated.emit(base_id, team_id, produces, total_units)

func _update_count_label() -> void:
	_prepare_count_label()
	if count_label == null:
		return

	if team_id == "neutral":
		count_label.text = "Def: %d" % defenders
	else:
		count_label.text = "%s: %d" % [_get_unit_short_name(), stored_units]

func _get_unit_short_name() -> String:
	match produces:
		"drone":
			return "D"
		"vehicle":
			return "V"
		_:
			return "S"

func _get_team_color() -> Color:
	match team_id:
		"player":
			return TeamManager.get_team_color(TeamManager.Team.PLAYER)
		"enemy":
			return TeamManager.get_team_color(TeamManager.Team.ENEMY)
		_:
			return TeamManager.get_team_color(TeamManager.Team.NEUTRAL)

func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var was_pressed := false
	if event is InputEventMouseButton:
		was_pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		was_pressed = event.pressed

	if was_pressed:
		selected.emit(base_id)
		get_viewport().set_input_as_handled()
