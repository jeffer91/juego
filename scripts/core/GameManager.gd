extends Node

signal game_state_changed(new_state: String)
signal level_loaded(level_number: int)
signal progress_changed(highest_unlocked_level: int)

const PROGRESS_PATH := "user://progress.cfg"

enum GameState {
	MENU,
	PLAYING,
	PAUSED,
	VICTORY,
	DEFEAT
}

var current_level: int = 1
var highest_unlocked_level: int = 1
var game_state: GameState = GameState.MENU

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_progress()

func start_game(level_number: int = 1) -> void:
	var safe_level := maxi(level_number, 1)
	if not has_level(safe_level):
		safe_level = 1
	current_level = safe_level
	get_tree().paused = false
	set_state(GameState.PLAYING)
	level_loaded.emit(current_level)

func pause_game() -> void:
	if game_state == GameState.PLAYING:
		set_state(GameState.PAUSED)
		get_tree().paused = true

func resume_game() -> void:
	if game_state == GameState.PAUSED:
		get_tree().paused = false
		set_state(GameState.PLAYING)

func register_victory() -> void:
	set_state(GameState.VICTORY)
	var next_level := current_level + 1
	if has_level(next_level) and next_level > highest_unlocked_level:
		highest_unlocked_level = next_level
		save_progress()
		progress_changed.emit(highest_unlocked_level)

func register_defeat() -> void:
	set_state(GameState.DEFEAT)

func restart_level() -> void:
	start_game(current_level)

func set_state(new_state: GameState) -> void:
	game_state = new_state
	game_state_changed.emit(get_state_name())

func get_state_name() -> String:
	match game_state:
		GameState.MENU:
			return "menu"
		GameState.PLAYING:
			return "playing"
		GameState.PAUSED:
			return "paused"
		GameState.VICTORY:
			return "victory"
		GameState.DEFEAT:
			return "defeat"
		_:
			return "unknown"

func has_level(level_number: int) -> bool:
	return FileAccess.file_exists("res://data/levels/level_%02d.json" % level_number)

func is_level_unlocked(level_number: int) -> bool:
	return level_number <= highest_unlocked_level and has_level(level_number)

func get_available_level_count() -> int:
	var level_number := 1
	while has_level(level_number):
		level_number += 1
	return level_number - 1

func load_progress() -> void:
	var config := ConfigFile.new()
	var error := config.load(PROGRESS_PATH)
	if error != OK:
		highest_unlocked_level = 1
		return

	highest_unlocked_level = maxi(1, int(config.get_value("progress", "highest_unlocked_level", 1)))
	highest_unlocked_level = mini(highest_unlocked_level, maxi(1, get_available_level_count()))

func save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "highest_unlocked_level", highest_unlocked_level)
	var error := config.save(PROGRESS_PATH)
	if error != OK:
		push_error("No se pudo guardar el progreso del juego.")
