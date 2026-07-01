extends Node2D

const RouteManagerScript := preload("res://scripts/movement/RouteManager.gd")
const PathFinderScript := preload("res://scripts/movement/PathFinder.gd")
const BaseFactoryScript := preload("res://scripts/bases/BaseFactory.gd")

const BACKGROUND_COLOR := Color(0.08, 0.10, 0.12)
const ROUTE_COLOR := Color(0.72, 0.72, 0.72)
const ROUTE_VALID_COLOR := Color(0.30, 0.85, 0.30, 0.18)
const ROUTE_WIDTH := 10.0
const ROUTE_VALID_WIDTH := 44.0

var route_manager: RouteManager
var path_finder: PathFinder
var base_factory: BaseFactory
var base_container: Node2D
var selected_base_id := ""

func _ready() -> void:
	route_manager = RouteManagerScript.new()
	route_manager.setup_level_01()

	path_finder = PathFinderScript.new()
	path_finder.configure(route_manager)

	base_factory = BaseFactoryScript.new()

	_build_game_layers()
	_spawn_bases()
	_build_hud_placeholder()

	GameManager.start_game(1)
	queue_redraw()

func _draw() -> void:
	_draw_background()
	_draw_route_valid_areas()
	_draw_routes()

func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), BACKGROUND_COLOR, true)

func _draw_route_valid_areas() -> void:
	for segment in route_manager.get_segment_positions():
		draw_line(
			segment["from_position"],
			segment["to_position"],
			ROUTE_VALID_COLOR,
			ROUTE_VALID_WIDTH
		)

func _draw_routes() -> void:
	for segment in route_manager.get_segment_positions():
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

func _spawn_bases() -> void:
	for base_data in route_manager.get_base_points():
		var spawn_position := route_manager.get_point(base_data["point_id"])
		var base := base_factory.create_base(base_data, spawn_position)
		base.selected.connect(_on_base_selected)
		base.owner_changed.connect(_on_base_owner_changed)
		base.unit_generated.connect(_on_base_unit_generated)
		base_container.add_child(base)

func _on_base_selected(base_id: String) -> void:
	selected_base_id = base_id
	print("Base seleccionada: %s" % base_id)

func _on_base_owner_changed(base_id: String, new_team_id: String) -> void:
	print("Base %s cambio a equipo %s" % [base_id, new_team_id])

func _on_base_unit_generated(base_id: String, team_id: String, unit_type: String, total_units: int) -> void:
	print("Base %s produjo %s para %s. Total: %d" % [base_id, unit_type, team_id, total_units])

func _build_hud_placeholder() -> void:
	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "HUDPlaceholder"
	add_child(canvas_layer)

	var title_label := Label.new()
	title_label.text = "Bloque 4 - Produccion automatica creada"
	title_label.position = Vector2(24, 18)
	canvas_layer.add_child(title_label)

	var instruction_label := Label.new()
	instruction_label.text = "Siguiente bloque: soldados reales"
	instruction_label.position = Vector2(24, 48)
	canvas_layer.add_child(instruction_label)

	var helper_label := Label.new()
	helper_label.text = "S = soldados acumulados | Def = defensores neutrales"
	helper_label.position = Vector2(24, 78)
	canvas_layer.add_child(helper_label)
