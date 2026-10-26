extends StaticBody3D
## Weapon lying on a table (scenes/items/pickup.tscn).
## The floor scene sets `weapon_id` on each instance; the matching model is shown.

@export_enum("rifle", "shotgun") var weapon_id := "rifle"

var taken := false


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("pickups")
	%RifleModel.visible = weapon_id == "rifle"
	%ShotgunModel.visible = weapon_id == "shotgun"


func get_prompt() -> String:
	return "[F] Take the gun" if weapon_id == "rifle" else "[F] Take the shotgun"


func interact_action() -> StringName:
	return &"px_interact"


func interact(player: Node) -> void:
	player.give_weapon(weapon_id)
	for other in get_tree().get_nodes_in_group("player"):      # 2 players: both get it
		if other != player and not other.has_weapon(weapon_id):
			other.give_weapon(weapon_id)
	if weapon_id == "rifle":
		GameManager.set_has_rifle()
	take_silently()


## Removes the weapon from the table (also used when loading a save).
func take_silently() -> void:
	taken = true
	remove_from_group("interactable")
	%RifleModel.visible = false
	%ShotgunModel.visible = false
