extends Node

class_name BaseSpawner

signal unit_generated(base_id: String, team_id: String, unit_type: String, total_units: int)
signal production_state_changed(base_id: String, is_active: bool)

var base_id := ""
var team_id := "neutral"
var unit_type := ""
var spawn_interval_seconds := 3.0
var stored_units := 0
var is_active := false

var production_timer: Timer

func _ready() -> void:
	_ensure_timer()
	_apply_timer_config()
	_refresh_production_state()

func configure(base_data: Dictionary) -> void:
	base_id = str(base_data.get("id", "base"))
	team_id = str(base_data.get("team", "neutral"))
	unit_type = str(base_data.get("produces", "soldier"))
	spawn_interval_seconds = float(base_data.get("spawn_interval_seconds", _get_default_interval(unit_type)))
	stored_units = int(base_data.get("initial_units", 0))

	_ensure_timer()
	_apply_timer_config()
	_refresh_production_state()

func update_team(new_team_id: String) -> void:
	team_id = new_team_id
	_refresh_production_state()

func add_units(amount: int) -> void:
	if amount <= 0:
		return

	stored_units += amount
	unit_generated.emit(base_id, team_id, unit_type, stored_units)

func consume_units(amount: int) -> int:
	var real_amount := clamp(amount, 0, stored_units)
	stored_units -= real_amount
	return real_amount

func get_stored_units() -> int:
	return stored_units

func can_produce() -> bool:
	return team_id != "neutral" and unit_type != ""

func _ensure_timer() -> void:
	if production_timer != null:
		return

	if has_node("ProductionTimer"):
		production_timer = $ProductionTimer
	else:
		production_timer = Timer.new()
		production_timer.name = "ProductionTimer"
		add_child(production_timer)

	if not production_timer.timeout.is_connected(_on_production_timer_timeout):
		production_timer.timeout.connect(_on_production_timer_timeout)

func _apply_timer_config() -> void:
	if production_timer == null:
		return

	production_timer.wait_time = max(spawn_interval_seconds, 0.2)
	production_timer.one_shot = false
	autostart = false

func _refresh_production_state() -> void:
	var should_be_active := can_produce()
	is_active = should_be_active

	if production_timer != null and is_inside_tree():
		if is_active:
			production_timer.start()
		else:
			production_timer.stop()

	production_state_changed.emit(base_id, is_active)

func _on_production_timer_timeout() -> void:
	if not can_produce():
		return

	add_units(1)

func _get_default_interval(type_id: String) -> float:
	match type_id:
		"drone":
			return 7.0
		"vehicle":
			return 8.0
		_:
			return 3.0
