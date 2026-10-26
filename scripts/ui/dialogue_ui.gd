extends CanvasLayer
## Dialogue box at the bottom of the screen with a typewriter effect (scenes/ui/dialogue_ui.tscn).

const CHARS_PER_SECOND := 45.0

var active := false

var _lines: Array = []
var _index := 0
var _on_finish := Callable()
var _opened_at := 0
var _closed_at := -10000

@onready var _panel: PanelContainer = %Panel
@onready var _name_label: Label = %NameLabel
@onready var _text_label: Label = %TextLabel
@onready var _hint_label: Label = %HintLabel


func _ready() -> void:
	add_to_group("dialogue_ui")
	_panel.visible = false


func show_dialogue(speaker: String, lines: Array, on_finish := Callable()) -> void:
	_lines = lines
	_index = 0
	_on_finish = on_finish
	_name_label.text = speaker
	active = true
	_opened_at = Time.get_ticks_msec()
	_panel.visible = true
	_show_line()


## True while the box is open or was closed a moment ago,
## so the key that closes it doesn't also start a new interaction.
func is_busy() -> bool:
	return active or Time.get_ticks_msec() - _closed_at < 300


func _process(delta: float) -> void:
	if active and _text_label.visible_ratio < 1.0:
		var total: int = max(_text_label.text.length(), 1)
		_text_label.visible_ratio = min(1.0, _text_label.visible_ratio + CHARS_PER_SECOND * delta / total)


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	# Ignore the same key press that opened the dialogue.
	if Time.get_ticks_msec() - _opened_at < 200:
		return
	var advance := event.is_action_pressed("px_talk") or event.is_action_pressed("px_interact") \
		or event.is_action_pressed("p2_talk") or event.is_action_pressed("p2_interact")
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance = true
	if advance:
		get_viewport().set_input_as_handled()
		_advance()


func _advance() -> void:
	if _text_label.visible_ratio < 1.0:
		_text_label.visible_ratio = 1.0
		return
	_index += 1
	if _index < _lines.size():
		_show_line()
		return
	active = false
	_closed_at = Time.get_ticks_msec()
	_panel.visible = false
	if _on_finish.is_valid():
		_on_finish.call()


func _show_line() -> void:
	_text_label.text = _lines[_index]
	_text_label.visible_ratio = 0.0
	_hint_label.text = "[E] continue" if _index < _lines.size() - 1 else "[E] close"

