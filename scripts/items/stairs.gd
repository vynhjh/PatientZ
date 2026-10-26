extends StaticBody3D
## Locked gate with the stairs to the next floor (scenes/items/stairs.tscn).
## It opens when GameManager.can_use_stairs(): Floor 1 cleared / Floor 2 mini-boss dead.
## Set `target_scene` and `next_floor_name` in the Inspector of each instance.

const Config = preload("res://scripts/systems/level_config.gd")

@export_file("*.tscn") var target_scene := Config.FLOOR_2_SCENE
@export var next_floor_name := "Floor 2"
@export var locked_text := "Eliminate the infected"

@onready var _light_mat: StandardMaterial3D = %LockLight.material_override


func _ready() -> void:
	add_to_group("interactable")


func _process(_delta: float) -> void:
	var color := Color.GREEN if GameManager.can_use_stairs() else Color.RED
	_light_mat.albedo_color = color
	_light_mat.emission = color


func get_prompt() -> String:
	if GameManager.can_use_stairs():
		return "[F] Go to %s" % next_floor_name
	if GameManager.floor_number == 1:
		return "[F] Locked · Eliminate the infected (%d/%d)" % [GameManager.kills, GameManager.kill_target]
	return "[F] Locked · " + locked_text


func interact_action() -> StringName:
	return &"px_interact"


func interact(player: Node) -> void:
	if not GameManager.can_use_stairs():
		GameManager.notify("The stairs are locked. %s first." % locked_text)
		return
	if ResourceLoader.exists(target_scene):
		GameManager.go_to_floor(target_scene, player)
	else:
		GameManager.notify("%s is not built yet (%s)" % [next_floor_name, target_scene])
