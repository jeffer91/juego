extends Node

class_name BaseSpawner

func _game_manager() -> Variant:
	return get_node("/root/GameManager")

signal unit_generated(base_id: String, team_id: String, unit_type: String, total_units: int)
signal units_changed(base_id: String, total_units: int)
signal production_state_changed(base_id: String, is_active: bool)

var base_id := ""
var team_id := "neutral"
var unit_type := ""
var spawn_interval_seconds := 3.0
var stored_units := 0
var max_units := 99
var is_active := false

var production_timer: Timer

func _ready() -> void:
	_ensure_timer()
	_apply_timer_config()

	if not _game_manager().game_state_changed.is_connected(_on_game_state_changed):
		_game_manager().game_state_changed.connect(_on_game_state_changed)

	_refresh_production_state()

func configure(base_data: Dictionary) -> void:
	base_id = str(base_data.get("id", "base"))
	team_id = str(base_data.get("team", "neutral"))
	unit_type = str(base_data.get("produces", "soldier"))
	spawn_interval_seconds = float(base_data.get("spawn_interval_seconds", 3.0))
	stored_units = maxi(0, int(base_data.get("initial_units", 0)))
	max_units = maxi(1, int(base_data.get("max_units", 99)))

	_ensure_timer()
	_apply_timer_config()
	units_changed.emit(base_id, stored_units)
	_refresh_production_state()

func update_team(new_team_id: String) -> void:
	team_id = new_team_id
	_refresh_production_state()

func add_units(amount: int) -> int:
	if amount <= 0:
		return 0

	var previous_units := stored_units
	stored_units = mini(max_units, stored_units + amount)
	var added := stored_units - previous_units

	if added > 0:
		units_changed.emit(base_id, stored_units)
		unit_generated.emit(base_id, team_id, unit_type, stored_units)

	return added

func consume_units(amount: int) -> int:
	if amount <= 0:
		return 0

	var consumed := mini(amount, stored_units)
	stored_units -= consumed

	if consumed > 0:
		units_changed.emit(base_id, stored_units)

	return consumed

func get_stored_units() -> int:
	return stored_units

func can_produce() -> bool:
	return team_id != "neutral" and not unit_type.is_empty() and _game_manager().get_state_name() == "playing"

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

	production_timer.wait_time = maxf(spawn_interval_seconds, 0.2)
	production_timer.one_shot = false
	production_timer.autostart = false

func _refresh_production_state() -> void:
	var should_be_active := can_produce()
	var state_changed := is_active != should_be_active
	is_active = should_be_active

	if production_timer != null and is_inside_tree():
		if is_active:
			if production_timer.is_stopped():
				production_timer.start()
		else:
			production_timer.stop()

	if state_changed:
		production_state_changed.emit(base_id, is_active)

func _on_game_state_changed(_new_state: String) -> void:
	_refresh_production_state()

func _on_production_timer_timeout() -> void:
	if not can_produce() or stored_units >= max_units:
		return
	add_units(1)
