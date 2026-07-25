extends RefCounted

class_name ContentLoader

const LEVEL_PATH_TEMPLATE := "res://data/levels/level_%02d.json"
const BASE_DEFINITION_PATHS := {
	"soldier": "res://data/bases/base_soldier.json",
	"drone": "res://data/bases/base_drone.json"
}
const UNIT_DEFINITION_PATHS := {
	"soldier": "res://data/units/soldier.json",
	"drone": "res://data/units/drone.json"
}

func level_exists(level_number: int) -> bool:
	return FileAccess.file_exists(LEVEL_PATH_TEMPLATE % level_number)

func load_level(level_number: int) -> Dictionary:
	var level_data := _read_json(LEVEL_PATH_TEMPLATE % level_number)
	if level_data.is_empty():
		return {}

	return _hydrate_level(level_data)

func load_base_definition(unit_type: String) -> Dictionary:
	var path := str(BASE_DEFINITION_PATHS.get(unit_type, ""))
	if path.is_empty():
		return {}
	return _read_json(path)

func load_unit_definition(unit_type: String) -> Dictionary:
	var path := str(UNIT_DEFINITION_PATHS.get(unit_type, ""))
	if path.is_empty():
		return {}
	return _read_json(path)

func _hydrate_level(level_data: Dictionary) -> Dictionary:
	var hydrated_level := level_data.duplicate(true)
	var hydrated_bases: Array = []

	for base_entry_value in hydrated_level.get("bases", []):
		var base_entry: Dictionary = base_entry_value
		var unit_type := str(base_entry.get("produces", "soldier"))
		var definition := load_base_definition(unit_type)
		var merged := definition.duplicate(true)

		if not definition.is_empty():
			merged["definition_id"] = str(definition.get("id", ""))

		merged.merge(base_entry, true)
		merged["produces"] = unit_type

		if not merged.has("spawn_interval_seconds"):
			merged["spawn_interval_seconds"] = 3.0

		if not merged.has("max_units"):
			merged["max_units"] = 99

		if str(merged.get("team", "neutral")) == "neutral" and not merged.has("defenders"):
			var difficulty := int(merged.get("difficulty", 0))
			var defenders_by_difficulty: Dictionary = merged.get("neutral_defenders_by_difficulty", {})
			merged["defenders"] = int(defenders_by_difficulty.get(str(difficulty), difficulty * 6))
		elif not merged.has("defenders"):
			merged["defenders"] = 0

		if not merged.has("initial_units"):
			merged["initial_units"] = 0

		hydrated_bases.append(merged)

	hydrated_level["bases"] = hydrated_bases
	return hydrated_level

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("No existe el archivo de datos: %s" % path)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("No se pudo abrir el archivo de datos: %s" % path)
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null or not (parsed is Dictionary):
		push_error("El JSON no es válido: %s" % path)
		return {}

	return parsed
