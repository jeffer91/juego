extends RefCounted

class_name RouteManager

var route_points := {}
var route_segments := []
var base_points := []

func setup_level_01() -> void:
	route_points = {
		"player_base": Vector2(160, 360),
		"enemy_base": Vector2(1120, 360),
		"neutral_top": Vector2(640, 170),
		"neutral_center": Vector2(640, 360),
		"neutral_bottom": Vector2(640, 550)
	}

	route_segments = [
		{"id": "upper_left", "route": "upper", "from": "player_base", "to": "neutral_top"},
		{"id": "upper_right", "route": "upper", "from": "neutral_top", "to": "enemy_base"},
		{"id": "center_left", "route": "center", "from": "player_base", "to": "neutral_center"},
		{"id": "center_right", "route": "center", "from": "neutral_center", "to": "enemy_base"},
		{"id": "bottom_left", "route": "bottom", "from": "player_base", "to": "neutral_bottom"},
		{"id": "bottom_right", "route": "bottom", "from": "neutral_bottom", "to": "enemy_base"}
	]

	base_points = [
		{
			"id": "player_base",
			"point_id": "player_base",
			"team": "player",
			"base_type": "main_player",
			"difficulty": 0,
			"produces": "soldier"
		},
		{
			"id": "enemy_base",
			"point_id": "enemy_base",
			"team": "enemy",
			"base_type": "main_enemy",
			"difficulty": 0,
			"produces": "soldier"
		},
		{
			"id": "neutral_top",
			"point_id": "neutral_top",
			"team": "neutral",
			"base_type": "soldier_base",
			"difficulty": 1,
			"produces": "soldier"
		},
		{
			"id": "neutral_center",
			"point_id": "neutral_center",
			"team": "neutral",
			"base_type": "drone_base",
			"difficulty": 2,
			"produces": "drone"
		},
		{
			"id": "neutral_bottom",
			"point_id": "neutral_bottom",
			"team": "neutral",
			"base_type": "soldier_base",
			"difficulty": 1,
			"produces": "soldier"
		}
	]

func get_point(point_id: String) -> Vector2:
	return route_points.get(point_id, Vector2.ZERO)

func get_base_points() -> Array:
	return base_points

func get_route_segments() -> Array:
	return route_segments

func get_segment_positions() -> Array:
	var result := []

	for segment in route_segments:
		result.append({
			"id": segment["id"],
			"route": segment["route"],
			"from": segment["from"],
			"to": segment["to"],
			"from_position": get_point(segment["from"]),
			"to_position": get_point(segment["to"])
		})

	return result

func is_point_on_route(point: Vector2, tolerance: float = 45.0) -> bool:
	var closest_point := get_closest_point_on_route(point)
	return point.distance_to(closest_point) <= tolerance

func get_closest_point_on_route(point: Vector2) -> Vector2:
	var best_point := Vector2.ZERO
	var best_distance := INF

	for segment in get_segment_positions():
		var candidate := get_closest_point_on_segment(
			point,
			segment["from_position"],
			segment["to_position"]
		)
		var distance := point.distance_to(candidate)

		if distance < best_distance:
			best_distance = distance
			best_point = candidate

	return best_point

func get_closest_point_on_segment(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> Vector2:
	var segment_vector := segment_end - segment_start
	var segment_length_squared := segment_vector.length_squared()

	if segment_length_squared == 0.0:
		return segment_start

	var projection := (point - segment_start).dot(segment_vector) / segment_length_squared
	var clamped_projection := clamp(projection, 0.0, 1.0)

	return segment_start + segment_vector * clamped_projection
