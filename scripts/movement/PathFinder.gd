extends RefCounted

class_name PathFinder

var route_manager: RouteManager

func configure(new_route_manager: RouteManager) -> void:
	route_manager = new_route_manager

func get_valid_destination(raw_destination: Vector2) -> Vector2:
	if route_manager == null:
		return raw_destination
	return route_manager.get_closest_point_on_route(raw_destination)

func is_valid_destination(raw_destination: Vector2) -> bool:
	if route_manager == null:
		return true
	return route_manager.is_point_on_route(raw_destination)

func build_path(start_position: Vector2, raw_destination: Vector2) -> Array:
	if route_manager == null:
		return [start_position, raw_destination]
	return route_manager.build_graph_path(start_position, raw_destination)

func build_simple_path(start_position: Vector2, raw_destination: Vector2) -> Array:
	return build_path(start_position, raw_destination)
