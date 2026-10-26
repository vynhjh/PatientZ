@tool
extends Node3D
## Words written with blood on a wall (scenes/props/wall_message.tscn).
## Change `text`, `size`, `style` and `messiness` in the Inspector of each instance.
## Every letter gets its own tilt, height and size (always the same for the same text),
## so it looks written by hand in a hurry. The drips follow the width.

const FONTS := {
	"scrawl": preload("res://assets/fonts/RockSalt-Regular.ttf"),        # written with a finger
	"dripping": preload("res://assets/fonts/RubikWetPaint-Regular.ttf"),  # wet, dripping paint
}

@export_multiline var text := "HELP US":
	set(value):
		text = value
		_refresh()
@export_range(0.5, 3.0) var size := 1.0:
	set(value):
		size = value
		_refresh()
@export_enum("scrawl", "dripping") var style := "scrawl":
	set(value):
		style = value
		_refresh()
@export_range(0.0, 1.0) var messiness := 0.6:
	set(value):
		messiness = value
		_refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_inside_tree() or not has_node("%Text"):
		return
	var template: Label3D = %Text
	var font: Font = FONTS.get(style, FONTS["scrawl"])
	template.font = font
	template.pixel_size = 0.004 * size
	template.text = text
	template.visible = false
	var letters := get_node_or_null("Letters")
	if letters:
		remove_child(letters)
		letters.free()
	letters = Node3D.new()
	letters.name = "Letters"
	add_child(letters)          # no owner: rebuilt every time, never saved in the scene

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(text) + hash(style)
	var px := template.pixel_size
	var lines := text.split("\n")
	var line_height := font.get_height(template.font_size) * px * 0.85
	var longest := 0.0
	for li in lines.size():
		var line: String = lines[li]
		var width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, template.font_size).x * px
		longest = maxf(longest, width)
		var x := -width / 2.0 + rng.randf_range(-0.1, 0.1) * size * messiness
		var y := (lines.size() - 1) * line_height / 2.0 - li * line_height
		var slope := rng.randf_range(-0.06, 0.06) * messiness     # each line runs a bit up or down
		for c in line:
			var advance := font.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, template.font_size).x * px
			if c != " ":
				var letter: Label3D = template.duplicate()
				letter.unique_name_in_owner = false
				letter.visible = true
				letter.text = c
				var s := 1.0 + rng.randf_range(-0.15, 0.25) * messiness
				letter.pixel_size = px * s
				letter.position = Vector3(x + advance / 2.0, y + x * slope + rng.randf_range(-0.05, 0.05) * size * messiness, 0.01 + rng.randf() * 0.002)
				letter.rotation.z = rng.randf_range(-0.22, 0.22) * messiness
				var m := letter.modulate
				m.a = clampf(m.a - rng.randf() * 0.25 * messiness, 0.5, 1.0)
				letter.modulate = m
				letters.add_child(letter)
			x += advance * (1.0 + rng.randf_range(-0.08, 0.12) * messiness)

	var drips: Decal = %Drips
	drips.size.x = clampf(longest * 1.05, 0.4, 4.5)
	drips.size.z = 0.6 + 0.4 * size
	drips.position.y = -lines.size() * line_height / 2.0 - drips.size.z / 2.0 + 0.1 * size
