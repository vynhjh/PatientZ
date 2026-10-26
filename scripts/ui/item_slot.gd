extends PanelContainer
## One slot of the item bar of the HUD (scenes/ui/item_slot.tscn).
## Set icon, key_text and title in the Inspector of each instance; the HUD calls set_state().

@export var icon: Texture2D:
	set(value):
		icon = value
		if is_node_ready():
			%Icon.texture = value
@export var key_text := "1":
	set(value):
		key_text = value
		if is_node_ready():
			%Key.text = value
@export var title := "Item"

const NORMAL_BORDER := Color(1, 1, 1, 0.25)
const SELECTED_BORDER := Color(1.0, 0.82, 0.3, 1.0)

var _style: StyleBoxFlat


func _ready() -> void:
	%Icon.texture = icon
	%Key.text = key_text
	_style = (get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	add_theme_stylebox_override("panel", _style)


## owned: the player has it (otherwise it is shown faded) · selected: the weapon in the hands
func set_state(owned: bool, selected: bool, count_text: String) -> void:
	%Icon.modulate = Color(1, 1, 1, 1.0 if owned else 0.25)
	%Count.text = count_text if count_text != "" else (title if owned else "")
	%Count.modulate = Color(1.0, 0.85, 0.4) if selected else Color(1, 1, 1, 0.85 if owned else 0.35)
	_style.border_color = SELECTED_BORDER if selected else NORMAL_BORDER
	_style.bg_color = Color(0.15, 0.12, 0.05, 0.8) if selected else Color(0.04, 0.05, 0.06, 0.72)
