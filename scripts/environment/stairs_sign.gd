@tool
extends Node3D
## Wall sign (scenes/environment/sign.tscn): a plate and a Label3D.
## The label is not a billboard and keeps the depth test on, so walls hide it.
## Change `text` / `size` / `text_color` in the Inspector of each instance (also visible in the editor).

@export_multiline var text := "STAIRS":
	set(value):
		text = value
		_refresh()
@export var size := Vector2(2.0, 0.5):
	set(value):
		size = value
		_refresh()
@export var text_color := Color(1.0, 0.92, 0.6):
	set(value):
		text_color = value
		_refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_inside_tree() or not has_node("%Label"):
		return
	var label: Label3D = %Label
	label.text = text
	label.modulate = text_color * 1.4
	var lines := text.split("\n")
	var longest := 1
	for line in lines:
		longest = maxi(longest, line.length())
	label.pixel_size = minf(size.y * 0.62 / (96.0 * lines.size()), size.x * 0.85 / (96.0 * 0.62 * longest))
	(%Plate.mesh as BoxMesh).size = Vector3(size.x, size.y, 0.05)
	%FrameTop.position.y = size.y / 2.0
	%FrameBottom.position.y = -size.y / 2.0
	(%FrameTop.mesh as BoxMesh).size = Vector3(size.x + 0.06, 0.03, 0.06)
	(%FrameBottom.mesh as BoxMesh).size = Vector3(size.x + 0.06, 0.03, 0.06)
