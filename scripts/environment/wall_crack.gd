@tool
extends Node3D
## Crack on a wall (scenes/props/wall_crack.tscn). Choose the shape in the Inspector.
## The Decal child projects onto the wall behind (-Z).

const SHAPES := [
	preload("res://assets/textures/crack_0.png"),
	preload("res://assets/textures/crack_1.png"),
	preload("res://assets/textures/crack_2.png"),
]

@export_range(0, 2) var shape := 0:
	set(value):
		shape = value
		_refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if is_inside_tree() and has_node("%Crack"):
		%Crack.texture_albedo = SHAPES[shape]
