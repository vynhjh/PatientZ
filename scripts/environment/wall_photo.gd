@tool
extends Node3D
## Photo taped to a wall (scenes/props/wall_photo.tscn). Choose the picture in the Inspector.

const PICTURES := [
	preload("res://assets/materials/prop_photo_0.tres"),
	preload("res://assets/materials/prop_photo_1.tres"),
	preload("res://assets/materials/prop_photo_2.tres"),
	preload("res://assets/materials/prop_photo_3.tres"),
]

@export_range(0, 3) var picture := 0:
	set(value):
		picture = value
		_refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if is_inside_tree() and has_node("%Picture"):
		%Picture.material_override = PICTURES[picture]
