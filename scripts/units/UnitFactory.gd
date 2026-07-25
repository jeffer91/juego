extends RefCounted

class_name UnitFactory

const UnitGroupScene := preload("res://scenes/units/UnitGroup.tscn")

func create_group(
	team_id: String,
	unit_type: String,
	unit_count: int,
	definition: Dictionary,
	spawn_position: Vector2
) -> UnitGroup:
	var group := UnitGroupScene.instantiate() as UnitGroup
	group.configure(team_id, unit_type, unit_count, definition, spawn_position)
	return group
