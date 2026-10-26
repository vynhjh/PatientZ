extends VBoxContainer
## List of saved games, shared by the main menu and the pause menu.
##   mode "load": click a saved game to load it · [Delete] removes it
##   mode "save": [+ New Save] creates a new saved game · click a saved game to overwrite it
## Asks for confirmation before overwriting or deleting.
## Layout in scenes/ui/save_slot_list.tscn; the rows (one per saved game) are created here.

signal slot_chosen(slot_id: String)      # load: the game to load · save: the slot to overwrite
signal new_slot_chosen                  # save mode: "+ New Save"
signal back_pressed

var mode := "load"
var title_text := "Saved Games"

var _pending_action := Callable()

@onready var _title: Label = %Title
@onready var _rows: VBoxContainer = %Rows
@onready var _empty: Label = %Empty
@onready var _confirm: ConfirmationDialog = %Confirm


## BackButton.pressed and Confirm.confirmed are connected in the scene (Node > Signals).
func _on_back_button_pressed() -> void:
	back_pressed.emit()


func open(list_mode: String, title: String) -> void:
	mode = list_mode
	title_text = title
	visible = true
	refresh()


func refresh() -> void:
	_title.text = title_text
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()

	if mode == "save":
		var new_button := Button.new()
		new_button.text = "+  New Save"
		new_button.custom_minimum_size = Vector2(0, 52)
		new_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		new_button.pressed.connect(func(): new_slot_chosen.emit())
		_rows.add_child(new_button)

	var slots := SaveManager.list_slots()
	_empty.visible = slots.is_empty() and mode == "load"
	for meta in slots:
		var slot_id: String = meta["id"]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_rows.add_child(row)

		var button := Button.new()
		button.text = SaveManager.describe(meta)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 58)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if slot_id == SaveManager.current_slot and get_tree().get_first_node_in_group("level") != null:
			button.text += "  ◀ current"
		button.pressed.connect(_on_slot_pressed.bind(slot_id))
		row.add_child(button)

		if mode == "load":
			var delete := Button.new()
			delete.text = "Delete"
			delete.custom_minimum_size = Vector2(80, 58)
			delete.pressed.connect(_on_delete_pressed.bind(slot_id))
			row.add_child(delete)

	if _rows.get_child_count() > 0:
		var first: Control = _rows.get_child(0) if mode == "save" else _rows.get_child(0).get_child(0)
		_focus.call_deferred(first)


static func _focus(control) -> void:
	if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree():
		control.grab_focus()


func _on_slot_pressed(slot_id: String) -> void:
	if mode == "save":
		_ask("Overwrite this saved game?", func(): slot_chosen.emit(slot_id))
	else:
		slot_chosen.emit(slot_id)


func _on_delete_pressed(slot_id: String) -> void:
	_ask("Delete this saved game?\nThis cannot be undone.", func():
		SaveManager.delete_slot(slot_id)
		refresh())


func _ask(text: String, action: Callable) -> void:
	_pending_action = action
	_confirm.dialog_text = text
	_confirm.popup_centered()


func _on_confirmed() -> void:
	if _pending_action.is_valid():
		_pending_action.call()
	_pending_action = Callable()
