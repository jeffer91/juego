extends CanvasLayer

class_name GameHUD

signal restart_pressed
signal next_level_pressed

var level_label: Label
var objective_label: Label
var selected_label: Label
var status_label: Label
var help_label: Label

var result_panel: Panel
var result_title: Label
var result_message: Label
var restart_button: Button
var next_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()

func configure_level(level_number: int, level_name: String, objective: String) -> void:
	_ensure_interface()
	level_label.text = "Nivel %d · %s" % [level_number, level_name]
	objective_label.text = objective
	selected_label.text = "Selección: ninguna"
	status_label.text = "Selecciona una base azul o un grupo."
	result_panel.visible = false

func set_selected_text(text: String) -> void:
	_ensure_interface()
	selected_label.text = "Selección: %s" % text

func set_status(text: String) -> void:
	_ensure_interface()
	status_label.text = text

func show_result(title: String, message: String, can_continue: bool) -> void:
	_ensure_interface()
	result_title.text = title
	result_message.text = message
	next_button.visible = can_continue
	result_panel.visible = true

func _ensure_interface() -> void:
	if level_label == null:
		_build_interface()

func _build_interface() -> void:
	if level_label != null:
		return

	var top_panel := Panel.new()
	top_panel.position = Vector2(16, 14)
	top_panel.size = Vector2(540, 132)
	add_child(top_panel)

	level_label = Label.new()
	level_label.position = Vector2(14, 10)
	level_label.size = Vector2(510, 28)
	level_label.add_theme_font_size_override("font_size", 20)
	top_panel.add_child(level_label)

	objective_label = Label.new()
	objective_label.position = Vector2(14, 40)
	objective_label.size = Vector2(510, 22)
	top_panel.add_child(objective_label)

	selected_label = Label.new()
	selected_label.position = Vector2(14, 66)
	selected_label.size = Vector2(510, 22)
	top_panel.add_child(selected_label)

	status_label = Label.new()
	status_label.position = Vector2(14, 92)
	status_label.size = Vector2(510, 28)
	top_panel.add_child(status_label)

	help_label = Label.new()
	help_label.position = Vector2(18, 678)
	help_label.size = Vector2(1120, 28)
	help_label.text = "Control: toca una base azul para enviar grupos; toca un grupo para moverlo; toca una base o una ruta como destino."
	add_child(help_label)

	result_panel = Panel.new()
	result_panel.position = Vector2(390, 220)
	result_panel.size = Vector2(500, 260)
	result_panel.visible = false
	add_child(result_panel)

	result_title = Label.new()
	result_title.position = Vector2(20, 22)
	result_title.size = Vector2(460, 42)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_font_size_override("font_size", 30)
	result_panel.add_child(result_title)

	result_message = Label.new()
	result_message.position = Vector2(30, 78)
	result_message.size = Vector2(440, 60)
	result_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_panel.add_child(result_message)

	restart_button = Button.new()
	restart_button.position = Vector2(62, 170)
	restart_button.size = Vector2(170, 52)
	restart_button.text = "Reintentar"
	restart_button.pressed.connect(_on_restart_pressed)
	result_panel.add_child(restart_button)

	next_button = Button.new()
	next_button.position = Vector2(268, 170)
	next_button.size = Vector2(170, 52)
	next_button.text = "Siguiente nivel"
	next_button.pressed.connect(_on_next_pressed)
	result_panel.add_child(next_button)

func _on_restart_pressed() -> void:
	restart_pressed.emit()

func _on_next_pressed() -> void:
	next_level_pressed.emit()
