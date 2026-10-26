extends Control
## Main menu (scenes/ui/MainMenu.tscn).
##   Main:      Play · Settings · Quit
##   Settings:  Volume (general and music) · Back
##   Play:      New Game · 1 Player · New Game · 2 Players (split screen) · Continue · Back
##   Continue:  list of saved games (load or delete) · Back
## New Game always starts in a new save slot, so the saved games are never touched.
## The layout and the button signals are in the scene. Drag your image into Background ›
## Texture and your music into Music › Stream; if they are empty, BACKGROUND_IMAGE and MUSIC
## are loaded when those files exist.

const SaveSlotList = preload("res://scripts/ui/save_slot_list.gd")

const GAME_SCENE := "res://main.tscn"
const BACKGROUND_IMAGE := "res://assets/img/menu.png"
const MUSIC := "res://assets/audio/menu_music.mp3"

@onready var _main_panel: VBoxContainer = %MainPanel
@onready var _play_panel: VBoxContainer = %PlayPanel
@onready var _continue_button: Button = %ContinueButton
@onready var _slots: VBoxContainer = %Slots
@onready var _settings: VBoxContainer = %SettingsMenu
@onready var _background: TextureRect = %Background
@onready var _music: AudioStreamPlayer = %Music


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	if _background.texture == null and ResourceLoader.exists(BACKGROUND_IMAGE):
		_background.texture = load(BACKGROUND_IMAGE)
	_play_music()
	_show(_main_panel)


func _show(panel: Control) -> void:
	_main_panel.visible = panel == _main_panel
	_play_panel.visible = panel == _play_panel
	_slots.visible = panel == _slots
	_settings.visible = panel == _settings
	if panel == _settings:
		_settings.open()
		return
	if panel == _play_panel:
		_continue_button.disabled = not SaveManager.has_any_save()
	if panel == _slots:
		_slots.open("load", "Continue · Saved Games")
	elif panel.get_child_count() > 0:
		SaveSlotList._focus.call_deferred(panel.get_child(0))


func _play_music() -> void:
	if _music.stream == null and ResourceLoader.exists(MUSIC):
		_music.stream = load(MUSIC)
	var stream := _music.stream
	if stream == null:
		return
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	elif "loop" in stream:
		stream.loop = true  # mp3 / ogg
	_music.play()


func _on_play_button_pressed() -> void:
	_show(_play_panel)


func _on_back_button_pressed() -> void:
	_show(_main_panel)


func _on_settings_button_pressed() -> void:
	_show(_settings)


func _on_settings_back_pressed() -> void:
	_show(_main_panel)


func _on_slots_back_pressed() -> void:
	_show(_play_panel)


## New game in a new slot: the saved games are not touched.
func _on_new_game_pressed() -> void:
	GameManager.player_count = 1
	SaveManager.start_new_game()
	_go_to_game()


## 2 players on the same screen: player 1 keyboard + mouse, player 2 gamepad (or numeric keypad).
func _on_new_game_2_players_pressed() -> void:
	GameManager.player_count = 2
	SaveManager.start_new_game()
	_go_to_game()


func _on_continue_pressed() -> void:
	_show(_slots)


func _on_slot_chosen(slot_id: String) -> void:
	if SaveManager.request_load(slot_id):
		_go_to_game()
	else:
		push_error("The saved game could not be loaded.")
		_slots.refresh()


func _go_to_game() -> void:
	if not ResourceLoader.exists(GAME_SCENE):
		push_error("Scene not found: " + GAME_SCENE)
		return
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_quit_button_pressed() -> void:
	get_tree().quit()
