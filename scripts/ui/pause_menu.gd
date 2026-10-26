extends CanvasLayer
## In-game pause menu ([Esc]): Resume · Save Game · Load Game · Main Menu.
##   Save Game → [+ New Save] or choose a saved game to overwrite
##   Load Game → choose any saved game to load
## The game is paused while it is open.
## Layout in scenes/ui/pause_menu.tscn; the buttons are connected there (Node > Signals).

const SaveSlotList = preload("res://scripts/ui/save_slot_list.gd")

const MENU_SCENE := "res://scenes/ui/MainMenu.tscn"
const GAME_SCENE := "res://main.tscn"

@onready var _root: Control = %Root
@onready var _main_panel: VBoxContainer = %MainPanel
@onready var _load_button: Button = %LoadButton
@onready var _info_label: Label = %InfoLabel
@onready var _slots: VBoxContainer = %Slots


func _ready() -> void:
	add_to_group("pause_menu")
	_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("px_pause"):
		var player := get_tree().get_first_node_in_group("player")
		if player and player._all_players_dead():
			return
		get_viewport().set_input_as_handled()
		if _root.visible and _slots.visible:
			_show_main()            # Esc inside a list goes back
		else:
			toggle()


func toggle() -> void:
	if _root.visible:
		resume()
	else:
		open()


func open() -> void:
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_main()


func resume() -> void:
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _show_main() -> void:
	_slots.visible = false
	_main_panel.visible = true
	_load_button.disabled = not SaveManager.has_any_save()
	var info := SaveManager.get_save_info()
	if info.is_empty():
		_info_label.text = "This game has not been saved yet"
	else:
		_info_label.text = "Last save of this game: %s" % str(info.get("saved_at", "")).replace("T", "  ")
	SaveSlotList._focus.call_deferred(%ResumeButton)


func _show_slots(mode: String) -> void:
	_main_panel.visible = false
	_slots.open(mode, "Save Game" if mode == "save" else "Load Game")


func _on_save_game_pressed() -> void:
	_show_slots("save")


func _on_load_pressed() -> void:
	_show_slots("load")


func _on_new_save() -> void:
	_save_to(SaveManager.NEW_SLOT)


func _on_slot_chosen(slot_id: String) -> void:
	if _slots.mode == "save":
		_save_to(slot_id)
		return
	if SaveManager.request_load(slot_id):
		get_tree().paused = false
		get_tree().change_scene_to_file(GAME_SCENE)


func _save_to(slot_id: String) -> void:
	var level := get_tree().get_first_node_in_group("level")
	if level and SaveManager.save_game(level, false, slot_id):
		_slots.refresh()


func _on_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)

