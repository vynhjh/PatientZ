extends Node
## Background soundtrack (autoload "Soundtrack", scenes/systems/soundtrack.tscn).
## The child "Music" plays assets/audio/soundtrack.mp3 in a loop from the moment the alarm
## goes off (after giving the syringes to the boss) and for the rest of the game: Floor 1
## after the alarm, Floor 2 and the next floors, also after loading a saved game.
## It is silent in the menus and before the alarm. Change the volume in the Music node.

const FADE_IN := 3.0
const FADE_OUT := 1.0

var _target_db := 0.0

@onready var _music: AudioStreamPlayer = $Music


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS       # keeps playing in the pause menu
	_target_db = _music.volume_db
	if "loop" in _music.stream:
		_music.stream.loop = true


func _process(delta: float) -> void:
	if _wanted():
		if not _music.playing:
			_music.volume_db = -40.0
			_music.play()
		_music.volume_db = move_toward(_music.volume_db, _target_db, 40.0 / FADE_IN * delta)
	elif _music.playing:
		_music.volume_db = move_toward(_music.volume_db, -40.0, 40.0 / FADE_OUT * delta)
		if _music.volume_db <= -39.0:
			_music.stop()


## In the game scene, once the alarm has started (Floor 1) or on any later floor.
func _wanted() -> bool:
	var scene := get_tree().current_scene
	if scene == null or scene.name != "Main" or get_tree().get_first_node_in_group("level") == null:
		return false
	return GameManager.floor_number >= 2 or GameManager.phase >= GameManager.Phase.SURVIVE
