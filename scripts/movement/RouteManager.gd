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
	var segment_info := _get_closest_segment_info(point)
	if segment_info.is_empty():
		return Vector2.ZERO
	return segment_info.get("projection", Vector2.ZERO)

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
	if route_points.is_empty() or route_segments.is_empty():
		return [start_position, raw_destination]

	var start_info := _get_closest_segment_info(start_position)
	var destination_info := _get_closest_segment_info(raw_destination)
	if start_info.is_empty() or destination_info.is_empty():
		return []

	var start_projection: Vector2 = start_info.get("projection", start_position)
	var destination_projection: Vector2 = destination_info.get("projection", raw_destination)
	var candidates: Array = []

	# Si ambos puntos están en el mismo tramo, el recorrido directo es válido y evita
	# que una unidad retroceda hasta un nodo para después volver por la misma ruta.
	if str(start_info.get("id", "")) == str(destination_info.get("id", "")):
		var direct_path: Array = []
		_append_unique_point(direct_path, start_position)
		_append_unique_point(direct_path, start_projection)
		_append_unique_point(direct_path, destination_projection)
		candidates.append(direct_path)

	var start_endpoints: Array = [
		{"id": str(start_info.get("from", "")), "position": start_info.get("from_position", Vector2.ZERO)},
		{"id": str(start_info.get("to", "")), "position": start_info.get("to_position", Vector2.ZERO)}
	]
	var destination_endpoints: Array = [
		{"id": str(destination_info.get("from", "")), "position": destination_info.get("from_position", Vector2.ZERO)},
		{"id": str(destination_info.get("to", "")), "position": destination_info.get("to_position", Vector2.ZERO)}
	]

	# Se prueban las cuatro combinaciones de extremos y se conserva la ruta más corta.
	# Así, una unidad que ya está en medio de un tramo nunca toma un desvío innecesario.
	for start_endpoint_value in start_endpoints:
		var start_endpoint: Dictionary = start_endpoint_value
		var start_id := str(start_endpoint.get("id", ""))
		if not point_numeric_ids.has(start_id):
			continue

		for destination_endpoint_value in destination_endpoints:
			var destination_endpoint: Dictionary = destination_endpoint_value
			var destination_id := str(destination_endpoint.get("id", ""))
			if not point_numeric_ids.has(destination_id):
				continue

			var id_path: PackedInt64Array = astar.get_id_path(
				int(point_numeric_ids[start_id]),
				int(point_numeric_ids[destination_id])
			)
			if id_path.is_empty():
				continue

			var candidate: Array = []
			_append_unique_point(candidate, start_position)
			_append_unique_point(candidate, start_projection)
			for numeric_id in id_path:
				_append_unique_point(candidate, astar.get_point_position(int(numeric_id)))
			_append_unique_point(candidate, destination_projection)
			candidates.append(candidate)

	var best_path: Array = []
	var best_length := INF
	for candidate_value in candidates:
		var candidate: Array = candidate_value
		var candidate_length := _get_path_length(candidate)
		if candidate_length < best_length:
			best_length = candidate_length
			best_path = candidate

	return best_path

func _get_closest_segment_info(point: Vector2) -> Dictionary:
	var best_segment: Dictionary = {}
	var best_distance := INF

	for segment_value in get_segment_positions():
		var segment: Dictionary = segment_value
		var projection := get_closest_point_on_segment(
			point,
			segment["from_position"],
			segment["to_position"]
		)
		var distance := point.distance_to(projection)
		if distance < best_distance:
			best_distance = distance
			best_segment = segment.duplicate(true)
			best_segment["projection"] = projection
			best_segment["distance"] = distance

	return best_segment

func _append_unique_point(path: Array, point: Vector2) -> void:
	if path.is_empty() or (path[-1] as Vector2).distance_to(point) > 1.0:
		path.append(point)

func _get_path_length(path: Array) -> float:
	var total := 0.0
	for index in range(1, path.size()):
		var previous: Vector2 = path[index - 1]
		var current: Vector2 = path[index]
		total += previous.distance_to(current)
	return total

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
