extends RefCounted

class_name RouteManager

const ContentLoaderScript := preload("res://scripts/data/ContentLoader.gd")

var route_points: Dictionary = {}
var route_segments: Array = []
var base_points: Array = []
var level_data: Dictionary = {}

var content_loader: ContentLoader
var astar := AStar2D.new()
var point_numeric_ids: Dictionary = {}
var numeric_point_ids: Dictionary = {}

func _init() -> void:
	content_loader = ContentLoaderScript.new()

func setup_level_01() -> void:
	setup_level(1)

func setup_level(level_number: int) -> bool:
	level_data = content_loader.load_level(level_number)
	if level_data.is_empty():
		return false

	route_points.clear()
	route_segments = level_data.get("routes", []).duplicate(true)
	base_points = level_data.get("bases", []).duplicate(true)

	for point_value in level_data.get("points", []):
		var point_data: Dictionary = point_value
		var point_id := str(point_data.get("id", ""))
		if point_id.is_empty():
			continue
		route_points[point_id] = Vector2(
			float(point_data.get("x", 0.0)),
			float(point_data.get("y", 0.0))
		)

	_build_graph()
	return not route_points.is_empty()

func get_level_number() -> int:
	return int(level_data.get("level_number", 1))

func get_level_name() -> String:
	return str(level_data.get("name", "Nivel"))

func get_level_description() -> String:
	return str(level_data.get("description", ""))

func get_level_settings() -> Dictionary:
	return level_data.get("settings", {})

func get_unit_definition(unit_type: String) -> Dictionary:
	return content_loader.load_unit_definition(unit_type)

func get_point(point_id: String) -> Vector2:
	return route_points.get(point_id, Vector2.ZERO)

func get_base_points() -> Array:
	return base_points

func get_base_data(base_id: String) -> Dictionary:
	for base_value in base_points:
		var base_data: Dictionary = base_value
		if str(base_data.get("id", "")) == base_id:
			return base_data
	return {}

func get_route_segments() -> Array:
	return route_segments

func get_segment_positions() -> Array:
	var result: Array = []

	for segment_value in route_segments:
		var segment: Dictionary = segment_value
		result.append({
			"id": str(segment.get("id", "")),
			"route": str(segment.get("route", "")),
			"from": str(segment.get("from", "")),
			"to": str(segment.get("to", "")),
			"from_position": get_point(str(segment.get("from", ""))),
			"to_position": get_point(str(segment.get("to", "")))
		})

	return result

func is_point_on_route(point: Vector2, tolerance: float = 45.0) -> bool:
	if route_segments.is_empty():
		return false
	return point.distance_to(get_closest_point_on_route(point)) <= tolerance

func get_closest_point_on_route(point: Vector2) -> Vector2:
	var best_point := Vector2.ZERO
	var best_distance := INF

	for segment_value in get_segment_positions():
		var segment: Dictionary = segment_value
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
	var clamped_projection := clampf(projection, 0.0, 1.0)
	return segment_start + segment_vector * clamped_projection

func get_nearest_point_id(position: Vector2) -> String:
	var best_id := ""
	var best_distance := INF

	for point_id_value in route_points.keys():
		var point_id := str(point_id_value)
		var distance := position.distance_to(get_point(point_id))
		if distance < best_distance:
			best_distance = distance
			best_id = point_id

	return best_id

func build_graph_path(start_position: Vector2, raw_destination: Vector2) -> Array:
	var result: Array = []
	if route_points.is_empty():
		return [start_position, raw_destination]

	var valid_destination := get_closest_point_on_route(raw_destination)
	var start_point_id := get_nearest_point_id(start_position)
	var destination_point_id := get_nearest_point_id(valid_destination)

	result.append(start_position)

	if point_numeric_ids.has(start_point_id) and point_numeric_ids.has(destination_point_id):
		var id_path := astar.get_id_path(
			int(point_numeric_ids[start_point_id]),
			int(point_numeric_ids[destination_point_id])
		)

		for numeric_id in id_path:
			var route_position := astar.get_point_position(int(numeric_id))
			if result[-1].distance_to(route_position) > 1.0:
				result.append(route_position)

	if result[-1].distance_to(valid_destination) > 1.0:
		result.append(valid_destination)

	return result

func _build_graph() -> void:
	astar.clear()
	point_numeric_ids.clear()
	numeric_point_ids.clear()

	var next_numeric_id := 1
	for point_id_value in route_points.keys():
		var point_id := str(point_id_value)
		point_numeric_ids[point_id] = next_numeric_id
		numeric_point_ids[next_numeric_id] = point_id
		astar.add_point(next_numeric_id, get_point(point_id))
		next_numeric_id += 1

	for segment_value in route_segments:
		var segment: Dictionary = segment_value
		var from_id := str(segment.get("from", ""))
		var to_id := str(segment.get("to", ""))
		if not point_numeric_ids.has(from_id) or not point_numeric_ids.has(to_id):
			continue

		var from_numeric := int(point_numeric_ids[from_id])
		var to_numeric := int(point_numeric_ids[to_id])
		if not astar.are_points_connected(from_numeric, to_numeric):
			astar.connect_points(from_numeric, to_numeric, true)
