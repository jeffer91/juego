extends Node

signal game_state_changed(new_state: String)
signal level_loaded(level_number: int)

enum GameState {
	MENU,
	PLAYING,
	PAUSED,
	VICTORY,
	DEFEAT
}

var current_level: int = 1
var game_state: GameState = GameState.MENU

func start_game(level_number: int = 1) -> void:
	current_level = max(level_number, 1)
	set_state(GameState.PLAYING)
	level_loaded.emit(current_level)

func pause_game() -> void:
	if game_state == GameState.PLAYING:
		set_state(GameState.PAUSED)

func resume_game() -> void:
	if game_state == GameState.PAUSED:
		set_state(GameState.PLAYING)

func register_victory() -> void:
	set_state(GameState.VICTORY)

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
