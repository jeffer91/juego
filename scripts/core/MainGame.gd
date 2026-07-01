extends Node2D

const RouteManagerScript := preload("res://scripts/movement/RouteManager.gd")
const PathFinderScript := preload("res://scripts/movement/PathFinder.gd")

const BACKGROUND_COLOR := Color(0.08, 0.10, 0.12)
const ROUTE_COLOR := Color(0.72, 0.72, 0.72)
const ROUTE_VALID_COLOR := Color(0.30, 0.85, 0.30, 0.18)
const BASE_RADIUS := 38.0
const ROUTE_WIDTH := 10.0
const ROUTE_VALID_WIDTH := 44.0

var route_manager: RouteManager
var path_finder: PathFinder

func _ready() -> void:
	route_manager = RouteManagerScript.new()
	route_manager.setup_level_01()

	path_finder = PathFinderScript.new()
	path_finder.configure(route_manager)

	_build_hud_placeholder()
	GameManager.start_game(1)
	queue_redraw()

func _draw() -> void:
	_draw_background()
	_draw_route_valid_areas()
	_draw_routes()
	_draw_bases()

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

func _draw_bases() -> void:
	for base_data in route_manager.get_base_points():
		_draw_base(base_data)

func _draw_base(base_data: Dictionary) -> void:
	var position := route_manager.get_point(base_data["point_id"])
	var team := _get_team_from_id(base_data.get("team", "neutral"))
	var color := TeamManager.get_team_color(team)

	draw_circle(position, BASE_RADIUS, color)
	draw_arc(position, BASE_RADIUS + 4.0, 0.0, TAU, 64, Color.WHITE, 3.0)

	if int(base_data.get("difficulty", 0)) > 0:
		draw_arc(position, BASE_RADIUS + 11.0, 0.0, TAU, 64, Color.YELLOW, 2.0)

	if str(base_data.get("produces", "")) == "drone":
		draw_circle(position + Vector2(0, -52), 9.0, Color.YELLOW)

func _get_team_from_id(team_id: String) -> TeamManager.Team:
	match team_id:
		"player":
			return TeamManager.Team.PLAYER
		"enemy":
			return TeamManager.Team.ENEMY
		_:
			return TeamManager.Team.NEUTRAL

func _build_hud_placeholder() -> void:
	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "HUDPlaceholder"
	add_child(canvas_layer)

	var title_label := Label.new()
	title_label.text = "Bloque 2 - Mapa y rutas creado"
	title_label.position = Vector2(24, 18)
	canvas_layer.add_child(title_label)

	var instruction_label := Label.new()
	instruction_label.text = "Siguiente bloque: bases reales y captura inicial"
	instruction_label.position = Vector2(24, 48)
	canvas_layer.add_child(instruction_label)

	var helper_label := Label.new()
	helper_label.text = "Verde suave = zona valida de movimiento futuro"
	helper_label.position = Vector2(24, 78)
	canvas_layer.add_child(helper_label)
