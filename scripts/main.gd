extends Node
## Game scene opened by the main menu (GAME_SCENE = "res://main.tscn").
## It opens the right floor as its child:
##   · a loaded saved game → the floor where it was saved
##   · the stairs of a floor → GameManager.next_floor_scene
##   · otherwise → first_floor (Floor 1)
## [Esc] opens the pause menu of the floor (Resume · Save Game · Load Game · Main Menu).

@export var first_floor: PackedScene = preload("res://scenes/levels/laboratorio_piso1.tscn")


func _ready() -> void:
	var scene: PackedScene = first_floor
	var path := ""
	if SaveManager.pending_load:
		path = SaveManager.pending_scene()
		GameManager.player_count = SaveManager.pending_players()
	elif GameManager.next_floor_scene != "":
		path = GameManager.next_floor_scene
	GameManager.next_floor_scene = ""
	if path != "" and ResourceLoader.exists(path):
		scene = load(path)
	if not SaveManager.pending_load and path == "":
		GameManager.carry_player = {}      # new game / restart: start fresh
		GameManager.carry_player2 = {}
	add_child(scene.instantiate())
