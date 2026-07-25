extends Node2D

class_name UnitGroup

signal selected(group: Node)
signal arrived(group: Node, target_base_id: String)
signal died(group: Node)
signal count_changed(group: Node, new_count: int)

const SELECTION_RADIUS := 34.0

var team_id := "neutral"
var unit_type := "soldier"
var unit_count := 0
var speed := 120.0
var attack_power := 1
var combat_radius := 72.0
var explosion_radius := 0.0
var can_capture_bases := true
var is_selected := false
var is_dead := false

var movement_path: Array = []
var movement_index := 0
var target_base_id := ""
var moving := false

var count_label: Label

func _ready() -> void:
	_prepare_label()
	_connect_click_area()
	_update_label()

func configure(
	new_team_id: String,
	new_unit_type: String,
	new_unit_count: int,
	definition: Dictionary,
	spawn_position: Vector2
) -> void:
	team_id = new_team_id
	unit_type = new_unit_type
	unit_count = maxi(0, new_unit_count)
	speed = float(definition.get("speed", 120.0))
	attack_power = maxi(1, int(definition.get("attack_power", 1)))
	combat_radius = float(definition.get("combat_radius", 72.0))
	explosion_radius = float(definition.get("explosion_radius", 0.0))
	can_capture_bases = bool(definition.get("can_capture", unit_type != "drone"))
	position = spawn_position
	name = "%s_%s_%d" % [team_id, unit_type, get_instance_id()]
	_prepare_label()
	_update_label()
	queue_redraw()

func move_along_path(new_path: Array, new_target_base_id: String = "") -> void:
	if is_dead or new_path.is_empty():
		return

	movement_path = new_path.duplicate()
	movement_index = 0
	target_base_id = new_target_base_id
	moving = true

	if movement_path.size() > 1 and position.distance_to(movement_path[0]) <= 8.0:
		movement_index = 1

func stop_moving() -> void:
	moving = false
	movement_path.clear()
	movement_index = 0
	target_base_id = ""

func set_selected(value: bool) -> void:
	is_selected = value
	queue_redraw()

func set_unit_count(value: int) -> void:
	unit_count = maxi(0, value)
	_update_label()
	count_changed.emit(self, unit_count)
	queue_redraw()
	if unit_count <= 0:
		destroy_group()

func take_casualties(amount: int) -> int:
	if is_dead or amount <= 0:
		return 0

	var removed := mini(amount, unit_count)
	unit_count -= removed
	_update_label()
	count_changed.emit(self, unit_count)
	queue_redraw()

	if unit_count <= 0:
		destroy_group()

	return removed

func destroy_group() -> void:
	if is_dead:
		return
	is_dead = true
	moving = false
	died.emit(self)
	queue_free()

func remove_after_transfer() -> void:
	if is_dead:
		return
	is_dead = true
	moving = false
	died.emit(self)
	queue_free()

func get_team_id() -> String:
	return team_id

func get_unit_type() -> String:
	return unit_type

func get_unit_count() -> int:
	return unit_count

func get_attack_power() -> int:
	return attack_power

func get_combat_radius() -> float:
	return combat_radius

func get_explosion_radius() -> float:
	return explosion_radius

func get_assault_strength() -> int:
	if is_drone():
		return attack_power
	return unit_count

func is_drone() -> bool:
	return unit_type == "drone"

func can_capture() -> bool:
	return can_capture_bases

func is_alive() -> bool:
	return not is_dead and unit_count > 0

func is_moving() -> bool:
	return moving

func _process(delta: float) -> void:
	if not moving or is_dead or GameManager.get_state_name() != "playing":
		return

	if movement_index >= movement_path.size():
		_finish_movement()
		return

	var destination: Vector2 = movement_path[movement_index]
	var distance := position.distance_to(destination)
	var step := speed * delta

	if distance <= step or distance <= 1.0:
		position = destination
		movement_index += 1
		if movement_index >= movement_path.size():
			_finish_movement()
	else:
		position += position.direction_to(destination) * step

func _finish_movement() -> void:
	moving = false
	movement_path.clear()
	movement_index = 0
	arrived.emit(self, target_base_id)
	target_base_id = ""

func _draw() -> void:
	var team_color := _get_team_color()

	if is_drone():
		var points := PackedVector2Array([
			Vector2(0, -15), Vector2(15, 0), Vector2(0, 15), Vector2(-15, 0)
		])
		draw_colored_polygon(points, team_color)
		draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color.WHITE, 2.0)
	else:
		var visible_units := mini(unit_count, 15)
		for index in range(visible_units):
			var column := index % 5
			var row := int(index / 5)
			var offset := Vector2((column - 2) * 8.0, (row - 1) * 8.0)
			draw_circle(offset, 3.2, team_color)

	if is_selected:
		draw_arc(Vector2.ZERO, SELECTION_RADIUS, 0.0, TAU, 48, Color(0.25, 0.95, 1.0), 3.0)

func _prepare_label() -> void:
	if count_label != null:
		return

	if has_node("CountLabel"):
		count_label = $CountLabel
	else:
		count_label = Label.new()
		count_label.name = "CountLabel"
		count_label.position = Vector2(-35, -48)
		count_label.size = Vector2(70, 22)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(count_label)

func _connect_click_area() -> void:
	if has_node("ClickArea") and not $ClickArea.input_event.is_connected(_on_click_area_input_event):
		$ClickArea.input_event.connect(_on_click_area_input_event)

func _update_label() -> void:
	_prepare_label()
	if count_label != null:
		count_label.text = "%s: %d" % ["D" if is_drone() else "S", unit_count]

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
		selected.emit(self)
		get_viewport().set_input_as_handled()
