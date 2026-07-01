extends Node2D

class_name Base

signal owner_changed(base_id: String, new_team_id: String)
signal selected(base_id: String)
signal unit_generated(base_id: String, team_id: String, unit_type: String, total_units: int)

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
	if has_node("ClickArea"):
		$ClickArea.input_event.connect(_on_click_area_input_event)

	_prepare_count_label()
	_prepare_spawner()
	_update_count_label()

func setup(base_data: Dictionary, spawn_position: Vector2) -> void:
	base_id = str(base_data.get("id", "base"))
	point_id = str(base_data.get("point_id", ""))
	team_id = str(base_data.get("team", "neutral"))
	base_type = str(base_data.get("base_type", "soldier_base"))
	produces = str(base_data.get("produces", "soldier"))
	difficulty = int(base_data.get("difficulty", 0))
	defenders = int(base_data.get("defenders", _get_default_defenders()))
	stored_units = int(base_data.get("initial_units", 0))

	position = spawn_position
	name = "Base_%s" % base_id

	_prepare_spawner()
	if spawner != null:
		var spawner_data := base_data.duplicate()
		spawner_data["spawn_interval_seconds"] = float(base_data.get("spawn_interval_seconds", _get_default_spawn_interval()))
		spawner.configure(spawner_data)
		stored_units = spawner.get_stored_units()

	_update_count_label()
	queue_redraw()

func set_owner(new_team_id: String) -> void:
	if team_id == new_team_id:
		return

	team_id = new_team_id

	if spawner != null:
		spawner.update_team(team_id)

	_update_count_label()
	owner_changed.emit(base_id, team_id)
	queue_redraw()

func set_selected(value: bool) -> void:
	is_selected = value
	queue_redraw()

func can_produce() -> bool:
	return team_id != "neutral" and produces != ""

func is_neutral() -> bool:
	return team_id == "neutral"

func is_player_base() -> bool:
	return team_id == "player"

func is_enemy_base() -> bool:
	return team_id == "enemy"

func is_main_base() -> bool:
	return base_type == "main_player" or base_type == "main_enemy"

func get_available_units() -> int:
	return stored_units

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
		draw_circle(Vector2(0, -52), 9.0, Color.YELLOW)
		draw_arc(Vector2(0, -52), 13.0, 0.0, TAU, 32, Color.WHITE, 2.0)

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
		count_label.position = Vector2(-44, -92)
		count_label.size = Vector2(88, 24)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(count_label)

func _prepare_spawner() -> void:
	if spawner != null:
		return

	if has_node("Spawner"):
		spawner = $Spawner

	if spawner == null:
		return

	if not spawner.unit_generated.is_connected(_on_spawner_unit_generated):
		spawner.unit_generated.connect(_on_spawner_unit_generated)

func _on_spawner_unit_generated(_base_id: String, _team_id: String, _unit_type: String, total_units: int) -> void:
	stored_units = total_units
	_update_count_label()
	unit_generated.emit(base_id, team_id, produces, stored_units)

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
			return "C"
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

func _get_default_defenders() -> int:
	if team_id != "neutral":
		return 0

	match difficulty:
		0:
			return 0
		1:
			return 5
		2:
			return 12
		_:
			return difficulty * 6

func _get_default_spawn_interval() -> float:
	match produces:
		"drone":
			return 7.0
		"vehicle":
			return 8.0
		_:
			return 3.0

func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		set_selected(not is_selected)
		selected.emit(base_id)

	if event is InputEventScreenTouch and event.pressed:
		set_selected(not is_selected)
		selected.emit(base_id)
