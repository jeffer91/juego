extends Node2D

const BACKGROUND_COLOR := Color(0.08, 0.10, 0.12)
const ROUTE_COLOR := Color(0.72, 0.72, 0.72)
const BASE_RADIUS := 38.0

var player_base_position := Vector2(160, 360)
var enemy_base_position := Vector2(1120, 360)
var neutral_top_position := Vector2(640, 170)
var neutral_center_position := Vector2(640, 360)
var neutral_bottom_position := Vector2(640, 550)

func _ready() -> void:
	_build_hud_placeholder()
	GameManager.start_game(1)
	queue_redraw()

func _draw() -> void:
	_draw_background()
	_draw_routes()
	_draw_bases()

func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), BACKGROUND_COLOR, true)

func _draw_routes() -> void:
	var line_width := 10.0

	draw_line(player_base_position, neutral_top_position, ROUTE_COLOR, line_width)
	draw_line(neutral_top_position, enemy_base_position, ROUTE_COLOR, line_width)

	draw_line(player_base_position, neutral_center_position, ROUTE_COLOR, line_width)
	draw_line(neutral_center_position, enemy_base_position, ROUTE_COLOR, line_width)

	draw_line(player_base_position, neutral_bottom_position, ROUTE_COLOR, line_width)
	draw_line(neutral_bottom_position, enemy_base_position, ROUTE_COLOR, line_width)

func _draw_bases() -> void:
	_draw_base(player_base_position, TeamManager.Team.PLAYER)
	_draw_base(enemy_base_position, TeamManager.Team.ENEMY)
	_draw_base(neutral_top_position, TeamManager.Team.NEUTRAL)
	_draw_base(neutral_center_position, TeamManager.Team.NEUTRAL)
	_draw_base(neutral_bottom_position, TeamManager.Team.NEUTRAL)

func _draw_base(position: Vector2, team: TeamManager.Team) -> void:
	var color := TeamManager.get_team_color(team)
	draw_circle(position, BASE_RADIUS, color)
	draw_arc(position, BASE_RADIUS + 4.0, 0.0, TAU, 64, Color.WHITE, 3.0)

func _build_hud_placeholder() -> void:
	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "HUDPlaceholder"
	add_child(canvas_layer)

	var title_label := Label.new()
	title_label.text = "Bloque 1 - Proyecto base creado"
	title_label.position = Vector2(24, 18)
	canvas_layer.add_child(title_label)

	var instruction_label := Label.new()
	instruction_label.text = "Siguiente bloque: mapa y rutas reales"
	instruction_label.position = Vector2(24, 48)
	canvas_layer.add_child(instruction_label)
