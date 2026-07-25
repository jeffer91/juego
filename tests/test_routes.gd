extends Node

const RouteManagerScript := preload("res://scripts/movement/RouteManager.gd")

var failures: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	_run_route_tests()
	_finish()

func _check(condition: bool, description: String) -> void:
	if condition:
		print("[OK] %s" % description)
		return
	failures.append(description)
	push_error("[FALLO] %s" % description)

func _run_route_tests() -> void:
	print("\n=== Verificación de rutas desde puntos intermedios ===")
	var manager: Variant = RouteManagerScript.new()
	_check(bool(manager.setup_level(1)), "Rutas: el nivel 1 puede cargarse")
	if manager.route_points.is_empty():
		return

	var player_position: Vector2 = manager.get_point("player_base")
	var top_position: Vector2 = manager.get_point("neutral_top")
	var bottom_position: Vector2 = manager.get_point("neutral_bottom")

	# Regresión: antes una orden corta dentro del mismo tramo hacía retroceder la
	# unidad hasta un nodo y recorrer de nuevo toda la ruta.
	var same_segment_start := player_position.lerp(top_position, 0.45)
	var same_segment_destination := player_position.lerp(top_position, 0.55)
	var same_segment_path: Array = manager.build_graph_path(same_segment_start, same_segment_destination)
	var direct_distance := same_segment_start.distance_to(same_segment_destination)
	_check(same_segment_path.size() == 2, "Rutas: un desplazamiento corto en el mismo tramo usa un recorrido directo")
	_check(
		_get_path_length(same_segment_path) <= direct_distance + 1.0,
		"Rutas: el recorrido intermedio no incluye retrocesos innecesarios"
	)
	_check(_path_stays_on_routes(manager, same_segment_path), "Rutas: el trayecto directo permanece sobre el tramo")

	# Entre dos rutas distintas, cada sección del recorrido debe seguir el grafo.
	var cross_start := player_position.lerp(top_position, 0.70)
	var cross_destination := player_position.lerp(bottom_position, 0.70)
	var cross_path: Array = manager.build_graph_path(cross_start, cross_destination)
	_check(cross_path.size() >= 3, "Rutas: un traslado entre rutas distintas incluye los nodos necesarios")
	_check(_path_stays_on_routes(manager, cross_path), "Rutas: el traslado entre rutas no atraviesa zonas fuera del mapa")

	# Los grupos se crean con una pequeña separación respecto de la base. La ruta
	# debe incorporarlos al tramo más cercano sin fallar.
	var offset_start := player_position + Vector2(18, 0)
	var offset_path: Array = manager.build_graph_path(offset_start, top_position)
	_check(offset_path.size() >= 2, "Rutas: un grupo desplazado alrededor de la base obtiene una ruta válida")
	_check(
		offset_path[-1].distance_to(top_position) <= 1.0,
		"Rutas: el recorrido termina exactamente en la base solicitada"
	)

func _path_stays_on_routes(manager: Variant, path: Array) -> bool:
	if path.size() < 2:
		return true
	for index in range(1, path.size()):
		var previous: Vector2 = path[index - 1]
		var current: Vector2 = path[index]
		var midpoint := (previous + current) * 0.5
		# El primer tramo puede ser la incorporación corta desde el desplazamiento
		# visual del grupo hacia la ruta.
		if index == 1 and not bool(manager.is_point_on_route(previous, 1.0)):
			continue
		if not bool(manager.is_point_on_route(midpoint, 1.5)):
			return false
	return true

func _get_path_length(path: Array) -> float:
	var total := 0.0
	for index in range(1, path.size()):
		var previous: Vector2 = path[index - 1]
		var current: Vector2 = path[index]
		total += previous.distance_to(current)
	return total

func _finish() -> void:
	if failures.is_empty():
		print("=== RESULTADO: las rutas intermedias funcionan correctamente ===\n")
		get_tree().quit(0)
		return

	printerr("=== RESULTADO: %d prueba(s) de rutas fallaron ===" % failures.size())
	for failure in failures:
		printerr("- %s" % failure)
	get_tree().quit(1)
