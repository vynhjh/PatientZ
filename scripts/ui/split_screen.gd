extends Control
## Split screen for 2 players (scenes/ui/split_screen.tscn, one in every floor scene).
## Left half: player 1 (keyboard + mouse) · right half: player 2 (gamepad / numeric keypad).
## Each half is a SubViewport that shows the same 3D world with its own Camera3D (it copies the
## camera of its player every frame) and its own HUD. In 1-player games it does nothing.

var _players: Array = []

@onready var _views := [%View1, %View2]
@onready var _cameras := [%Camera1, %Camera2]


## Called by the floor in 2-player games.
func setup(player1: Node3D, player2: Node3D) -> void:
	_players = [player1, player2]
	visible = true
	var world := get_viewport().world_3d
	for view in _views:
		view.world_3d = world
	get_viewport().disable_3d = true          # only the two halves draw the 3D world
	_sync_cameras()


func _process(_delta: float) -> void:
	if not _players.is_empty():
		_sync_cameras()


func _sync_cameras() -> void:
	for i in _players.size():
		var player = _players[i]
		if not is_instance_valid(player):
			continue
		var source: Camera3D = player.camera_rig.camera
		_cameras[i].global_transform = source.global_transform
		_cameras[i].fov = source.fov


func _exit_tree() -> void:
	if not _players.is_empty() and get_viewport():
		get_viewport().disable_3d = false
