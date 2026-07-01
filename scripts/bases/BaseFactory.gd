extends RefCounted

class_name BaseFactory

const BaseScene := preload("res://scenes/bases/Base.tscn")

func create_base(base_data: Dictionary, spawn_position: Vector2) -> Base:
	var base := BaseScene.instantiate() as Base
	base.setup(base_data, spawn_position)
	return base
