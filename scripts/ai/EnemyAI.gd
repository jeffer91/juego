extends Node

class_name EnemyAI

func _game_manager() -> Variant:
	return get_node("/root/GameManager")

var controller: Node
var action_interval := 4.0
var action_timer: Timer

func _ready() -> void:
	_ensure_timer()

func configure(game_controller: Node, interval_seconds: float) -> void:
	controller = game_controller
	action_interval = maxf(interval_seconds, 1.0)
	_ensure_timer()
	action_timer.wait_time = action_interval

func start() -> void:
	_ensure_timer()
	if action_timer != null:
		action_timer.start()

func stop() -> void:
	if action_timer != null:
		action_timer.stop()

func _ensure_timer() -> void:
	if action_timer != null:
		return

	action_timer = Timer.new()
	action_timer.name = "EnemyActionTimer"
	action_timer.one_shot = false
	action_timer.autostart = false
	add_child(action_timer)
	action_timer.timeout.connect(_on_action_timer_timeout)

func _on_action_timer_timeout() -> void:
	if controller == null or _game_manager().get_state_name() != "playing":
		return
	if controller.has_method("run_enemy_ai_turn"):
		controller.run_enemy_ai_turn()
