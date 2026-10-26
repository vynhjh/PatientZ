extends StaticBody3D
## The boss of Floor 1 (scenes/npc/jefe.tscn). Gives the syringe task, then the keycard.
## Model: assets/npc/doctor.fbx (node Model/Doctor). Its animation "Take 001" (writing on the
## clipboard) plays in a loop, and he turns towards the player when you talk to him.

const DialogueDB = preload("res://scripts/systems/dialogue_db.gd")
const IDLE_ANIMATION := "Take 001"
const CHARACTER_LAYER := 2        # blood decals don't stain him

@onready var _model: Node3D = %Model


func _ready() -> void:
	add_to_group("interactable")
	for mesh in _model.find_children("*", "MeshInstance3D", true, false):
		mesh.layers = CHARACTER_LAYER
	var players := _model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		var anim_player: AnimationPlayer = players[0]
		if anim_player.has_animation(IDLE_ANIMATION):
			anim_player.get_animation(IDLE_ANIMATION).loop_mode = Animation.LOOP_LINEAR
			anim_player.play(IDLE_ANIMATION)


func get_prompt() -> String:
	return "[E] to talk with your boss"


func interact_action() -> StringName:
	return &"px_talk"


func interact(player: Node3D) -> void:
	var dialogue := get_tree().get_first_node_in_group("dialogue_ui")
	if dialogue == null or dialogue.is_busy():
		return
	_face(player.global_position)

	match GameManager.phase:
		GameManager.Phase.INTRO:
			dialogue.show_dialogue(DialogueDB.BOSS_NAME, DialogueDB.BOSS_INTRO, _on_intro_finished)
		GameManager.Phase.COLLECT:
			if GameManager.has_all_syringes():
				GameManager.deliver_syringes()  # starts the alarm
				dialogue.show_dialogue(DialogueDB.BOSS_NAME, DialogueDB.BOSS_ALARM, GameManager.give_keycard)
			else:
				dialogue.show_dialogue(DialogueDB.BOSS_NAME, [
					DialogueDB.BOSS_MISSING_SYRINGES % [GameManager.syringes, GameManager.SYRINGES_NEEDED],
				])
		GameManager.Phase.SURVIVE:
			dialogue.show_dialogue(DialogueDB.BOSS_NAME, [DialogueDB.BOSS_SURVIVE])
		GameManager.Phase.CLEARED:
			dialogue.show_dialogue(DialogueDB.BOSS_NAME, [DialogueDB.BOSS_CLEARED])


func _on_intro_finished() -> void:
	GameManager.set_phase(GameManager.Phase.COLLECT)
	GameManager.notify("The first 4 rooms are now open")


func _face(target: Vector3) -> void:
	var flat := Vector3(target.x, global_position.y, target.z)
	if flat.distance_to(global_position) > 0.1:
		look_at(flat, Vector3.UP)
		rotate_y(PI)  # the model's front is +Z
